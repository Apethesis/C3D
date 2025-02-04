local function build_run(c3d,args)
    if not c3d.run then
        function c3d.run()
            local ds = c3d.sys.get_bus().graphics.display_source
            if c3d.load then c3d.load(table.unpack(args,1,args.n)) end
            if c3d.timer then c3d.timer.step() end
            local dt = 0
            return function()
                if c3d.event then
                    for name, a,b,c,d,e,f in c3d.event.poll() do
                        if name == "quit" then
                            if not c3d.quit or not c3d.quit() then
                                return a or 0
                            end
                        end
                        c3d.handlers[name](a,b,c,d,e,f)
                    end
                end
                if c3d.timer then dt = c3d.timer.step() end
                if c3d.update then c3d.update(dt) end
                ds.setVisible(false)
                c3d.graphics.clear_buffer(c3d.graphics.get_bg())

                if c3d.render then c3d.render() end
                c3d.graphics.render_frame()
                if c3d.timer then c3d.timer.sleep(c3d.sys.get_bus().sys.frame_time_min) end
                if c3d.postrender then c3d.postrender(ds) end
                ds.setVisible(true)
            end
        end
    end
end

return build_run
