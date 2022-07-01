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
        self.assertAlmostEqual(beta_with, 34616, -2)

    def test_reciruclating_withdrawal(self):
        """
        Test for reciruclating_withdrawal
        """
        beta_with = wc.recirculating_withdrawal(
            eta_net=0.20,
            k_os=0.25,
            beta_proc=200,
            eta_cc=5,
            k_sens=0.15
        )
        self.assertAlmostEqual(beta_with, 4486, -2)

    def test_get_k_sens(self):
        """
        Test for getting k_sens
        """
        self.assertAlmostEqual(wc.get_k_sens(t_inlet=22), 0.17, 2)
        self.assertAlmostEqual(wc.get_k_sens(t_inlet=30), 0.10, 2)


if __name__ == '__main__':
    unittest.main()
