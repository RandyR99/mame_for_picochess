"""Start MAME and add Novag mechanical audio through the Linux default device."""
from array import array
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
from tempfile import TemporaryDirectory
from threading import Event, Thread
import wave

RATE = 44100
BLOCK = 882  # 20 ms
TONES = Path(__file__).resolve().parent


def load_tone(filename, gain, loop_margin=0, overlap=0):
    with wave.open(str(TONES / filename), "rb") as wav:
        if (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) != (1, 2, RATE):
            raise ValueError(f"Unexpected PCM format in {filename}")
        pcm = array("h")
        pcm.frombytes(wav.readframes(wav.getnframes()))
    if sys.byteorder != "little":
        pcm.byteswap()
    pcm = [round(gain * value) for value in pcm]
    if not overlap:
        return pcm
    end = len(pcm) - loop_margin
    loop = pcm[loop_margin:end - overlap]
    for frame in range(overlap):
        weight = frame / overlap
        loop[frame] = round(pcm[end - overlap + frame] * (1 - weight) + loop[frame] * weight)
    return loop


class Loop:
    def __init__(self, samples):
        self.samples = samples
        self.position = 0
        self.level = 0
        self.playing = False

    def render(self, mix):
        step = 1 / (RATE * (0.03 if self.playing else 0.05))
        for i in range(len(mix)):
            self.level = min(1, self.level + step) if self.playing else max(0, self.level - step)
            if self.level == 0:
                self.position = 0
                break
            mix[i] += round(self.samples[self.position] * self.level)
            self.position = (self.position + 1) % len(self.samples)


def play_events(events, player, stop):
    loops = {
        "motor": Loop(load_tone("motor.wav", .34, int(.13 * RATE), int(.09 * RATE))),
        "lift": Loop(load_tone("lift.wav", .30, int(.02 * RATE), int(.035 * RATE))),
    }
    clicks = {
        "grip": load_tone("grip.wav", .43),
        "release": load_tone("release.wav", .43),
    }
    playing = {}
    with events.open("rb") as stream:
        while not stop.is_set():
            for line in iter(stream.readline, b""):
                event = line.strip().decode("ascii")
                if event == "silence":
                    playing.clear()
                    for loop in loops.values():
                        loop.playing = False
                elif event in clicks:
                    playing[event] = 0
                else:
                    name, _, state = event.partition("_")
                    if name in loops:
                        loops[name].playing = state == "on"

            mix = [0] * BLOCK
            for loop in loops.values():
                if loop.playing or loop.level:
                    loop.render(mix)
            for name, start in tuple(playing.items()):
                samples = clicks[name]
                block = samples[start:start + BLOCK]
                for i, value in enumerate(block):
                    mix[i] += value
                if len(block) < BLOCK:
                    del playing[name]
                else:
                    playing[name] += BLOCK
            stereo = array("h")
            for value in mix:
                value = max(-32768, min(32767, value))
                stereo.extend((value, value))
            if sys.byteorder != "little":
                stereo.byteswap()
            player.stdin.write(stereo.tobytes())


def launcher(command):
    if not shutil.which("aplay"):
        print("NovagAudio: aplay is missing. Install the alsa-utils package on the Pi.", file=sys.stderr)
        os.execvp(command[0], command)
    with TemporaryDirectory(prefix="novag-sound-") as temp:
        events = Path(temp) / "events"
        events.touch()
        env = dict(os.environ, NOVAG_SOUND_EVENTS=str(events))
        player = subprocess.Popen(
            ["aplay", "-q", "-D", env.get("NOVAG_ALSA_DEVICE", "default"),
             "-t", "raw", "-f", "S16_LE", "-r", str(RATE), "-c", "2",
             "--buffer-time=80000", "--period-time=20000"],
            stdin=subprocess.PIPE, bufsize=0, start_new_session=True,
        )
        stop = Event()

        def play():
            try:
                play_events(events, player, stop)
            except (OSError, ValueError) as exc:
                if not stop.is_set():
                    print(f"NovagAudio: {exc}", file=sys.stderr)

        thread = Thread(target=play, daemon=True)
        thread.start()
        try:
            machine = subprocess.Popen(command, env=env)

            def forward(signum, _frame):
                if machine.poll() is None:
                    machine.send_signal(signum)

            signal.signal(signal.SIGTERM, forward)
            signal.signal(signal.SIGINT, forward)
            result = machine.wait()
            return 128 - result if result < 0 else result
        finally:
            stop.set()
            if player.poll() is None:
                player.terminate()
                try:
                    player.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    player.kill()
                    player.wait()
            thread.join(timeout=2)


if __name__ == "__main__":
    if len(sys.argv) < 3 or sys.argv[1] != "--":
        sys.exit("Usage: python3 novag_audio.py -- /path/to/mess [MAME options]")
    sys.exit(launcher(sys.argv[2:]))
