<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesFinanceData;
use Tests\TestCase;

class ReportTest extends TestCase
{
    use CreatesFinanceData, RefreshDatabase;

    public function test_monthly_report_totals_and_expense_breakdown(): void
    {
        $this->seedMonth($this->signIn());

        $response = $this->getJson('/api/reports/monthly?month=2026-10')
            ->assertOk()
            ->assertJsonPath('data.month', '2026-10')
            ->assertJsonPath('data.total_income', 5000000)
            ->assertJsonPath('data.total_expense', 485000)
            ->assertJsonPath('data.net', 4515000)
            ->assertJsonPath('data.transaction_count', 6);

        $rows = $response->json('data.expense_by_category');

        $this->assertCount(4, $rows);
        $this->assertSame(['Belanja', 'Makan & Minum', 'Hiburan', 'Transportasi'], array_column($rows, 'name'));
        $this->assertSame([250000, 105000, 100000, 30000], array_column($rows, 'total'));
        $this->assertEquals([51.5, 21.6, 20.6, 6.2], array_column($rows, 'percentage'));
    }

    public function test_monthly_report_for_another_month_only_counts_that_month(): void
    {
        $this->seedMonth($this->signIn());

        $this->getJson('/api/reports/monthly?month=2026-09')
            ->assertOk()
            ->assertJsonPath('data.total_income', 0)
            ->assertJsonPath('data.total_expense', 80000)
            ->assertJsonPath('data.net', -80000)
            ->assertJsonPath('data.transaction_count', 1);
    }

    public function test_month_boundaries_are_inclusive_of_the_last_day_only(): void
    {
        $user = $this->signIn();
        $wallet = $this->wallet($user);

        $this->expense($user, $wallet, 'Makan & Minum', 1000, '2026-10-31');
        $this->expense($user, $wallet, 'Makan & Minum', 2000, '2026-11-01');

        $this->getJson('/api/reports/monthly?month=2026-10')->assertJsonPath('data.total_expense', 1000);
        $this->getJson('/api/reports/monthly?month=2026-11')->assertJsonPath('data.total_expense', 2000);
    }

    public function test_other_users_transactions_are_not_counted(): void
    {
        $other = $this->makeUser();
        $this->expense($other, $this->wallet($other), 'Makan & Minum', 999999, '2026-10-18');

        $this->seedMonth($this->signIn());

        $this->getJson('/api/reports/monthly?month=2026-10')
            ->assertJsonPath('data.total_expense', 485000);
    }

    public function test_daily_report_has_one_entry_per_day_including_empty_days(): void
    {
        $this->seedMonth($this->signIn());

        $response = $this->getJson('/api/reports/daily?month=2026-10')
            ->assertOk()
            ->assertJsonCount(31, 'data')
            ->assertJsonPath('data.0.date', '2026-10-01')
            ->assertJsonPath('data.0.income', 0)
            ->assertJsonPath('data.0.expense', 0)
            ->assertJsonPath('data.17.date', '2026-10-18')
            ->assertJsonPath('data.17.income', 5000000)
            ->assertJsonPath('data.17.expense', 145000)
            ->assertJsonPath('data.18.date', '2026-10-19')
            ->assertJsonPath('data.18.expense', 340000);

        $this->assertSame('2026-10-31', $response->json('data.30.date'));
    }

    public function test_export_returns_a_csv_with_every_transaction_of_the_month(): void
    {
        $this->seedMonth($this->signIn());

        $response = $this->get('/api/reports/export?month=2026-10')->assertOk();

        $this->assertStringContainsString('text/csv', $response->headers->get('Content-Type'));

        $csv = $response->streamedContent();
        $lines = array_values(array_filter(explode("\n", trim($csv))));

        $this->assertCount(8, $lines);
        $this->assertStringContainsString('Tanggal,Tipe,Dompet', $lines[0]);
        $this->assertStringContainsString('Pemasukan', $csv);
        $this->assertStringContainsString('Transfer', $csv);
        $this->assertStringContainsString('Pengeluaran', $csv);
    }

    public function test_export_neutralises_notes_that_look_like_spreadsheet_formulas(): void
    {
        $user = $this->signIn();
        $wallet = $this->wallet($user);

        $this->expense($user, $wallet, 'Makan & Minum', 1000, '2026-10-18', '=1+1');

        $csv = $this->get('/api/reports/export?month=2026-10')->assertOk()->streamedContent();

        $this->assertStringContainsString("'=1+1", $csv);
        $this->assertStringNotContainsString(',=1+1', $csv);
    }

    public function test_invalid_month_is_rejected(): void
    {
        $this->signIn();

        $this->getJson('/api/reports/monthly?month=2026-13')->assertUnprocessable();
        $this->getJson('/api/reports/daily?month=oktober')->assertUnprocessable();
    }

    private function seedMonth(User $user): void
    {
        $bca = $this->wallet($user, 'BCA', 2000000);
        $cash = $this->cashWallet($user);

        $this->addTransaction($user, [
            'wallet_id' => $bca->id,
            'type' => 'income',
            'category_id' => $this->category($user, 'Gaji', 'income')->id,
            'amount' => 5000000,
            'transaction_date' => '2026-10-18',
            'note' => 'Gaji Oktober',
        ]);
        $this->addTransaction($user, [
            'wallet_id' => $bca->id,
            'to_wallet_id' => $cash->id,
            'type' => 'transfer',
            'amount' => 500000,
            'transaction_date' => '2026-10-18',
            'note' => 'Tarik tunai',
        ]);

        $this->expense($user, $bca, 'Makan & Minum', 45000, '2026-10-18', 'Makan siang');
        $this->expense($user, $bca, 'Hiburan', 100000, '2026-10-18', 'Nonton');
        $this->expense($user, $bca, 'Belanja', 250000, '2026-10-19', 'Belanja bulanan');
        $this->expense($user, $bca, 'Makan & Minum', 60000, '2026-10-19', 'Makan malam');
        $this->expense($user, $bca, 'Transportasi', 30000, '2026-10-19', 'Ojek');
        $this->expense($user, $bca, 'Makan & Minum', 80000, '2026-09-30', 'Makan bulan lalu');
    }

    private function expense($user, $wallet, string $category, int $amount, string $date, ?string $note = null): void
    {
        $this->addTransaction($user, [
            'wallet_id' => $wallet->id,
            'type' => 'expense',
            'category_id' => $this->category($user, $category, 'expense')->id,
            'amount' => $amount,
            'transaction_date' => $date,
            'note' => $note,
        ]);
    }
}