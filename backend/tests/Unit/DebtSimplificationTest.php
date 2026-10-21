<?php

namespace Tests\Unit;

use App\Services\GroupBalanceService;
use PHPUnit\Framework\TestCase;

class DebtSimplificationTest extends TestCase
{
    public function test_two_people_need_a_single_payment(): void
    {
        $payments = (new GroupBalanceService())->simplify([1 => 140000, 2 => -140000]);

        $this->assertSame([['from' => 2, 'to' => 1, 'amount' => 140000]], $payments);
    }

    public function test_two_debtors_pay_the_same_creditor(): void
    {
        $payments = (new GroupBalanceService())->simplify([1 => 100, 2 => -60, 3 => -40]);

        $this->assertSame([
            ['from' => 2, 'to' => 1, 'amount' => 60],
            ['from' => 3, 'to' => 1, 'amount' => 40],
        ], $payments);
    }

    public function test_settled_group_needs_no_payments(): void
    {
        $this->assertSame([], (new GroupBalanceService())->simplify([1 => 0, 2 => 0, 3 => 0]));
    }

    public function test_payments_settle_every_balance_with_few_transfers(): void
    {
        $cases = [
            [1 => 30, 2 => -10, 3 => -50, 4 => 30],
            [1 => 600, 2 => -200, 3 => -100, 4 => -300, 5 => 0],
            [1 => -1, 2 => 1],
            [1 => 7, 2 => 7, 3 => -3, 4 => -11],
            [1 => 1, 2 => 1, 3 => 1, 4 => -3],
        ];

        foreach ($cases as $balances) {
            $payments = (new GroupBalanceService())->simplify($balances);

            $left = $balances;
            foreach ($payments as $payment) {
                $this->assertGreaterThan(0, $payment['amount']);
                $left[$payment['from']] += $payment['amount'];
                $left[$payment['to']] -= $payment['amount'];
            }

            $this->assertSame(array_fill_keys(array_keys($balances), 0), $left);

            $nonZero = count(array_filter($balances, fn (int $balance) => $balance !== 0));
            $this->assertLessThanOrEqual(max(0, $nonZero - 1), count($payments));
        }
    }
}