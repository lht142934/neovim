local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local plugin_helpers = require('test.functional.plugin.helpers')

local command = helpers.command

describe('health.vim', function()
  before_each(function()
    plugin_helpers.reset()
    -- Provides functions:
    --    health#broken#check()
    --    health#success1#check()
    --    health#success2#check()
    command("set runtimepath+=test/functional/fixtures")
  end)

  it("reports", function()
    helpers.source([[
      let g:health_report = execute([
        \ "call health#report_start('Check Bar')",
        \ "call health#report_ok('Bar status')",
        \ "call health#report_ok('Other Bar status')",
        \ "call health#report_warn('Zub')",
        \ "call health#report_start('Baz')",
        \ "call health#report_warn('Zim', ['suggestion 1', 'suggestion 2'])"
        \ ])
    ]])
    local result = helpers.eval("g:health_report")

    helpers.eq(helpers.dedent([[


      ## Check Bar
        - OK: Bar status
        - OK: Other Bar status
        - WARNING: Zub

      ## Baz
        - WARNING: Zim
          - ADVICE:
            - suggestion 1
            - suggestion 2]]),
      result)
  end)


  describe(":CheckHealth", function()
    it("concatenates multiple reports", function()
      command("CheckHealth success1 success2")
      helpers.expect([[

        health#success1#check
        ========================================================================
        ## report 1
          - OK: everything is fine

        ## report 2
          - OK: nothing to see here

        health#success2#check
        ========================================================================
        ## another 1
          - OK: ok
        ]])
    end)

    it("gracefully handles broken healthcheck", function()
      command("CheckHealth broken")
      helpers.expect([[

        health#broken#check
        ========================================================================
          - ERROR: Failed to run healthcheck for "broken" plugin. Exception:
            function health#check[21]..health#broken#check, line 1
            caused an error
        ]])
    end)

    it("highlights OK, ERROR", function()
      local screen = Screen.new(72, 10)
      screen:attach()
      screen:set_default_attr_ids({
        Ok = { foreground = Screen.colors.Grey3, background = 6291200 },
        Error = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
      })
      screen:set_default_attr_ignore({
        Heading = { bold=true, foreground=Screen.colors.Magenta },
        Heading2 = { foreground = Screen.colors.SlateBlue },
        Bar = { foreground=Screen.colors.Purple },
        Bullet = { bold=true, foreground=Screen.colors.Brown },
      })
      command("CheckHealth foo success1")
      command("1tabclose")
      command("set laststatus=0")
      screen:expect([[
        ^                                                                        |
        health#foo#check                                                        |
        ========================================================================|
          - {Error:ERROR:} No healthcheck found for "foo" plugin.                       |
                                                                                |
        health#success1#check                                                   |
        ========================================================================|
        ## report 1                                                             |
          - {Ok:OK:} everything is fine                                              |
                                                                                |
      ]])
    end)

    it("gracefully handles invalid healthcheck", function()
      command("CheckHealth non_existent_healthcheck")
      helpers.expect([[

        health#non_existent_healthcheck#check
        ========================================================================
          - ERROR: No healthcheck found for "non_existent_healthcheck" plugin.
        ]])
    end)
  end)
end)
