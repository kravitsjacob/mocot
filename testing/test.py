"""Test for core"""

import unittest
import wc


class CoreTest(unittest.TestCase):
    def test_once_through_withdrawal(self):
        """
        Test for once_through_withdrawal
        """
        beta_with = wc.once_through_withdrawal(
            eta_net=0.25,
            k_os=0.25,
            delta_t=5,
            beta_proc=200
        )
        self.assertAlmostEquals(beta_with, 34616, -2)


if __name__ == '__main__':
    unittest.main()
