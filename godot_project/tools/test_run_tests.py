import unittest

from run_tests import parse_args


class GodotArgumentsTest(unittest.TestCase):
    def test_posix_executable_is_never_a_suite_filter(self):
        for executable in ("/usr/local/bin/godot", "/Applications/Godot.app/Contents/MacOS/Godot"):
            for option in (["--godot", executable], [f"--godot={executable}"]):
                for filters in ([], ["save_pause"]):
                    with self.subTest(option=option, filters=filters):
                        args = parse_args([*option, *filters])
                        self.assertEqual(args.godot, executable)
                        self.assertEqual(args.filters, filters)
