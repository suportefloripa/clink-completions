package.path = "modules/?.lua;".. package.path
local color = require('color')
local telescope = require('telescope')

describe("color module", function()
    
    it("should define color constants", function()
        assert_equal(color.BLACK,   0)
        assert_equal(color.RED,     1)
        assert_equal(color.GREEN,   2)
        assert_equal(color.YELLOW,  3)
        assert_equal(color.BLUE,    4)
        assert_equal(color.MAGENTA, 5)
        assert_equal(color.CYAN,    6)
        assert_equal(color.WHITE,   7)
        assert_equal(color.DEFAULT, 9)
        assert_equal(color.BOLD,    1)
    end)

    it("should export methods", function()
        assert_type(color.set_color, 'function')
        assert_type(color.color_text, 'function')
    end)

    describe("'set_color' method", function ()

        local VALID_COLOR_STRING = "^\x1b%[(3%d);(%d%d?);(4%d)m$"

        it("should accept numeric arguments and return string", function ()
            assert_type(color.set_color(1, 2, 3), "string")
        end)

        it("should accept nil arguments and still return string", function ()
            assert_type(color.set_color(), "string")
        end)

        it("should throw if first two arguments are not a numbers or nil", function ()
            assert_error(function() color.set_color('a', 2, 3) end)
            assert_error(function() color.set_color(1, 'a', 3) end)
        end)

        it("should throw if arguments is out of range", function ()
            assert_error(function() color.set_color(100, 1, 1) end)
            assert_error(function() color.set_color(1, 200, 1) end)
        end)

        it("should return valid ANSI color code", function ()
            assert_match(VALID_COLOR_STRING, color.set_color(3, 2, 1))
        end)

        it("should set color to DEFAULT if no corresponding argument was passed", function ()
            local _, _, fore, bold, back = string.find(color.set_color(), VALID_COLOR_STRING)
            assert_equal(fore, "39");
            assert_equal(back, "49");
            assert_equal(bold, "22");
        end)
    end)

    describe("'color_text' method", function ()

        local TEST_STRING = "abc"
        local VALID_COLOR_STRING = "\x1b%[3%d;%d%d?;4%dm"

        it("should wrap string into valid ANSI codes", function ()
            assert_match("^"..VALID_COLOR_STRING..TEST_STRING..VALID_COLOR_STRING.."$",
                color.color_text(TEST_STRING, 1, 2, 3))
        end)

        it("should reset color to default", function ()
            local _,_, color_suffix = string.find(color.color_text(TEST_STRING, 1, 2, 3),
                "^"..VALID_COLOR_STRING..TEST_STRING.."("..VALID_COLOR_STRING..")$")
            assert_equal(color_suffix, color.set_color())
        end)
    end)
end)