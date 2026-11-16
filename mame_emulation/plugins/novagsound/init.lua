local plugin = {}
local subscriptions = {}

function plugin.startplugin()
    local event_path = os.getenv("NOVAG_SOUND_EVENTS")

    local last_x, last_y, last_open, last_motion
    local motor, lift = false, false
    local lever_counter, last_phase

    -- Fresh output proxy per access (output.get_value/set_value are
    -- deprecated). Don't keep proxies: they point into the machine's
    -- output storage.
    local function output(machine, name)
        return machine.devices[":"]:output(name)
    end

    local function publish_lever(machine)
        if lever_counter == nil then
            local driver = machine.devices[":"]
            local items = driver and driver.items
            local index = items and items["0/m_counter"]
            local item = index and emu.item and emu.item(index)
            lever_counter = item and item.size == 4 and item.count == 4 and item or false
        end
        if not lever_counter then return end
        local phase = lever_counter:read(1) % 2000000 + 1
        if phase ~= last_phase then
            output(machine, "novag_lift_phase"):set(phase)
            last_phase = phase
        end
    end

    local function send(event)
        if not event_path then return end
        local stream, err = io.open(event_path, "ab")
        if not stream then
            emu.print_error("Novag sound: " .. err)
            return
        end
        stream:write(event, "\n")
        stream:close()
    end

    local function set_motor(moving)
        if moving ~= motor then
            motor = moving
            send(moving and "motor_on" or "motor_off")
        end
    end

    local function silence()
        last_phase = nil
        motor, lift = false, false
        last_x, last_y, last_open, last_motion = nil, nil, nil, nil
        send("silence")
    end

    subscriptions.frame = emu.add_machine_frame_notifier(function()
        local machine = manager.machine
        if machine.system.name ~= "robotadv" or machine.paused then return end
        publish_lever(machine)
        if not event_path then return end

        local position = output(machine, "pos_x"):get()
        local x, y = position & 0x7ff, output(machine, "pos_y"):get()
        if y == 0 then return end

        local now = machine.time:as_double()
        local open = (position & 0x800) ~= 0
        -- motor1 is the vertical lever; the arm rotations still share the
        -- original position-driven travel sound.
        local lifting = output(machine, "motor1"):get() ~= 0
        if lifting ~= lift then
            lift = lifting
            send(lift and "lift_on" or "lift_off")
        end
        if last_x then
            if x ~= last_x or y ~= last_y then
                last_motion = now
                set_motor(true)
            elseif last_motion and now - last_motion >= 0.085 then
                set_motor(false)
            end
            if open ~= last_open then
                send(open and "release" or "grip")
            end
        end
        last_x, last_y, last_open = x, y, open
    end)
    subscriptions.pause = emu.add_machine_pause_notifier(silence)
    subscriptions.reset = emu.add_machine_reset_notifier(silence)
    subscriptions.stop = emu.add_machine_stop_notifier(function()
        lever_counter = nil
        silence()
    end)
    if emu.add_machine_post_load_notifier then
        subscriptions.load = emu.add_machine_post_load_notifier(silence)
    end
end

return plugin
