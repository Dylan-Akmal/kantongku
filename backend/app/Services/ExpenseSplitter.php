<?php

namespace App\Services;

use Illuminate\Validation\ValidationException;

class ExpenseSplitter
{
    /**
     * Menghitung porsi tiap peserta. Seluruh nominal dalam rupiah bulat.
     * Sisa pembulatan dibebankan ke pembayar bila ia ikut jadi peserta,
     * jika tidak, ke peserta pertama dalam daftar.
     *
     * @return array<int, int> user_id => amount_owed
     */
    public function split(string $type, int $total, int $payerId, array $participants): array
    {
        $ids = array_map(fn (array $p) => (int) $p['user_id'], $participants);
        $remainderTo = in_array($payerId, $ids, true) ? $payerId : $ids[0];

        return match ($type) {
            'equal' => $this->equal($total, $ids, $remainderTo),
            'exact' => $this->exact($total, $participants),
            'percent' => $this->percent($total, $participants, $remainderTo),
            default => throw ValidationException::withMessages([
                'split_type' => ['Mode pembagian tidak dikenal.'],
            ]),
        };
    }

    private function equal(int $total, array $ids, int $remainderTo): array
    {
        $count = count($ids);
        $base = intdiv($total, $count);
        $remainder = $total - ($base * $count);

        $shares = [];
        foreach ($ids as $id) {
            $shares[$id] = $base;
        }
        $shares[$remainderTo] += $remainder;

        return $shares;
    }

    private function exact(int $total, array $participants): array
    {
        $shares = [];
        foreach ($participants as $p) {
            $shares[(int) $p['user_id']] = (int) $p['amount'];
        }

        $sum = array_sum($shares);
        if ($sum !== $total) {
            throw ValidationException::withMessages([
                'participants' => ["Jumlah porsi ($sum) harus sama dengan total ($total)."],
            ]);
        }

        return $shares;
    }

    private function percent(int $total, array $participants, int $remainderTo): array
    {
        // Persen disimpan sebagai basis poin (1% = 100) agar bebas galat pecahan.
        $points = [];
        foreach ($participants as $p) {
            $points[(int) $p['user_id']] = (int) round(((float) $p['percent']) * 100);
        }

        if (array_sum($points) !== 10000) {
            throw ValidationException::withMessages([
                'participants' => ['Jumlah persen seluruh peserta harus tepat 100.'],
            ]);
        }

        $shares = [];
        foreach ($points as $userId => $point) {
            $shares[$userId] = intdiv($total * $point, 10000);
        }
        $shares[$remainderTo] += $total - array_sum($shares);

        return $shares;
    }
}