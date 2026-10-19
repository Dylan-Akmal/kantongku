<?php

namespace App\Support;

use Illuminate\Support\Carbon;

class Period
{
    /**
     * Mengembalikan [awal bulan, akhir bulan] dari teks "YYYY-MM".
     * Jika kosong, dipakai bulan berjalan.
     *
     * @return array{0: Carbon, 1: Carbon}
     */
    public static function month(?string $month): array
    {
        $start = $month
            ? Carbon::createFromFormat('Y-m-d', $month.'-01')->startOfDay()
            : now()->startOfMonth();

        return [$start, $start->copy()->endOfMonth()];
    }
}