"""Main analysis script"""

import wc


def main():
    wc.once_through_withdrawal(
        eta_net=0.25,
        k_os=0.25,
        delta_t=5,
        beta_proc=200
    )


if __name__ == '__main__':
    main()
