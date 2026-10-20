<?php

namespace App\Services;

use App\Models\ExpenseShare;
use App\Models\GroupExpense;
use App\Models\Settlement;
use App\Models\SplitGroup;

class GroupBalanceService
{
    /**
     * Saldo bersih tiap anggota grup, dalam rupiah.
     * Positif: masih harus menerima uang. Negatif: masih berutang.
     *
     * @return array<int, int> user_id => saldo
     */
    public function balances(SplitGroup $group): array
    {
        $memberIds = $group->memberships()->pluck('user_id');

        $paid = GroupExpense::where('group_id', $group->id)
            ->selectRaw('paid_by, SUM(total_amount) as total')
            ->groupBy('paid_by')
            ->pluck('total', 'paid_by');

        $owed = ExpenseShare::query()
            ->join('group_expenses', 'group_expenses.id', '=', 'expense_shares.expense_id')
            ->where('group_expenses.group_id', $group->id)
            ->whereNull('group_expenses.deleted_at')
            ->selectRaw('expense_shares.user_id as user_id, SUM(expense_shares.amount_owed) as total')
            ->groupBy('expense_shares.user_id')
            ->pluck('total', 'user_id');

        $sent = Settlement::where('group_id', $group->id)
            ->selectRaw('from_user_id, SUM(amount) as total')
            ->groupBy('from_user_id')
            ->pluck('total', 'from_user_id');

        $received = Settlement::where('group_id', $group->id)
            ->selectRaw('to_user_id, SUM(amount) as total')
            ->groupBy('to_user_id')
            ->pluck('total', 'to_user_id');

        $result = [];

        foreach ($memberIds as $id) {
            $result[$id] = (int) ($paid[$id] ?? 0)
                - (int) ($owed[$id] ?? 0)
                + (int) ($sent[$id] ?? 0)
                - (int) ($received[$id] ?? 0);
        }

        return $result;
    }

    public function balanceOf(SplitGroup $group, int $userId): int
    {
        return $this->balances($group)[$userId] ?? 0;
    }

    /**
     * Daftar pembayaran sesedikit mungkin untuk menutup semua saldo:
     * yang paling banyak berutang membayar yang paling banyak piutangnya.
     *
     * @param  array<int, int>  $balances
     * @return array<int, array{from: int, to: int, amount: int}>
     */
    public function simplify(array $balances): array
    {
        $creditors = [];
        $debtors = [];

        foreach ($balances as $userId => $balance) {
            if ($balance > 0) {
                $creditors[] = ['id' => $userId, 'amount' => $balance];
            } elseif ($balance < 0) {
                $debtors[] = ['id' => $userId, 'amount' => -$balance];
            }
        }

        $byAmountDesc = fn (array $a, array $b) => $b['amount'] <=> $a['amount'];
        usort($creditors, $byAmountDesc);
        usort($debtors, $byAmountDesc);

        $payments = [];
        $i = 0;
        $j = 0;

        while ($i < count($debtors) && $j < count($creditors)) {
            $pay = min($debtors[$i]['amount'], $creditors[$j]['amount']);

            $payments[] = [
                'from' => $debtors[$i]['id'],
                'to' => $creditors[$j]['id'],
                'amount' => $pay,
            ];

            $debtors[$i]['amount'] -= $pay;
            $creditors[$j]['amount'] -= $pay;

            if ($debtors[$i]['amount'] === 0) {
                $i++;
            }
            if ($creditors[$j]['amount'] === 0) {
                $j++;
            }
        }

        return $payments;
    }
}