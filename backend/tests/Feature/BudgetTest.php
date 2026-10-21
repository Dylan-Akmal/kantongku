<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesFinanceData;
use Tests\TestCase;

class BudgetTest extends TestCase
{
    use CreatesFinanceData, RefreshDatabase;

    public function test_setting_a_budget_creates_it_and_setting_it_again_updates_it(): void
    {
        $user = $this->signIn();
        $belanja = $this->category($user, 'Belanja', 'expense');
        $payload = ['category_id' => $belanja->id, 'month' => '2026-10', 'amount' => 200000];

        $this->postJson('/api/budgets', $payload)
            ->assertCreated()
            ->assertJsonPath('message', 'Anggaran berhasil dibuat.')
            ->assertJsonPath('data.amount', 200000);

        $this->postJson('/api/budgets', array_merge($payload, ['amount' => 250000]))
            ->assertOk()
            ->assertJsonPath('message', 'Anggaran berhasil diperbarui.')
            ->assertJsonPath('data.amount', 250000);

        $this->assertDatabaseCount('budgets', 1);
        $this->assertDatabaseHas('budgets', ['user_id' => $user->id, 'month' => '2026-10-01', 'amount' => 250000]);
    }

    public function test_spent_is_calculated_from_the_expenses_of_that_month(): void
    {
        $user = $this->signIn();
        $wallet = $this->wallet($user, 'BCA', 2000000);
        $belanja = $this->category($user, 'Belanja', 'expense');
        $makan = $this->category($user, 'Makan & Minum', 'expense');

        $this->addTransaction($user, [
            'wallet_id' => $wallet->id, 'category_id' => $belanja->id,
            'amount' => 250000, 'transaction_date' => '2026-10-19',
        ]);
        $this->addTransaction($user, [
            'wallet_id' => $wallet->id, 'category_id' => $belanja->id,
            'amount' => 80000, 'transaction_date' => '2026-09-30',
        ]);
        $this->addTransaction($user, [
            'wallet_id' => $wallet->id, 'category_id' => $makan->id,
            'amount' => 45000, 'transaction_date' => '2026-10-18',
        ]);

        $this->postJson('/api/budgets', ['category_id' => $belanja->id, 'month' => '2026-10', 'amount' => 200000])
            ->assertCreated();
        $this->postJson('/api/budgets', ['category_id' => $makan->id, 'month' => '2026-10', 'amount' => 100000])
            ->assertCreated();

        $response = $this->getJson('/api/budgets?month=2026-10')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.total_budget', 300000)
            ->assertJsonPath('meta.total_spent', 295000);

        $items = collect($response->json('data'))->keyBy(fn (array $item) => $item['category']['name']);

        $this->assertSame(250000, $items['Belanja']['spent']);
        $this->assertSame(-50000, $items['Belanja']['remaining']);
        $this->assertTrue($items['Belanja']['is_over']);
        $this->assertEquals(125, $items['Belanja']['percentage']);

        $this->assertSame(45000, $items['Makan & Minum']['spent']);
        $this->assertSame(55000, $items['Makan & Minum']['remaining']);
        $this->assertFalse($items['Makan & Minum']['is_over']);
        $this->assertEquals(45, $items['Makan & Minum']['percentage']);
    }

    public function test_list_only_shows_budgets_of_the_requested_month(): void
    {
        $user = $this->signIn();
        $belanja = $this->category($user, 'Belanja', 'expense');

        $this->postJson('/api/budgets', ['category_id' => $belanja->id, 'month' => '2026-10', 'amount' => 200000])
            ->assertCreated();

        $this->getJson('/api/budgets?month=2026-09')
            ->assertOk()
            ->assertJsonCount(0, 'data')
            ->assertJsonPath('meta.total_spent', 0);
    }

    public function test_invalid_budgets_are_rejected(): void
    {
        $other = $this->makeUser();
        $otherCategory = $this->category($other, 'Belanja', 'expense');

        $user = $this->signIn();
        $belanja = $this->category($user, 'Belanja', 'expense');
        $gaji = $this->category($user, 'Gaji', 'income');
        $valid = ['category_id' => $belanja->id, 'month' => '2026-10', 'amount' => 200000];

        $cases = [
            'category_id' => ['category_id' => $gaji->id],
            'month' => ['month' => '2026-13'],
            'amount' => ['amount' => 0],
        ];

        foreach ($cases as $field => $override) {
            $this->postJson('/api/budgets', array_merge($valid, $override))
                ->assertUnprocessable()
                ->assertJsonValidationErrors($field);
        }

        $this->postJson('/api/budgets', array_merge($valid, ['category_id' => $otherCategory->id]))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('category_id');
    }

    public function test_budget_can_be_deleted_only_by_its_owner(): void
    {
        $other = $this->makeUser();
        $foreign = $other->budgets()->create([
            'category_id' => $this->category($other, 'Belanja', 'expense')->id,
            'month' => '2026-10-01',
            'amount' => 1000,
        ]);

        $user = $this->signIn();
        $belanja = $this->category($user, 'Belanja', 'expense');

        $id = $this->postJson('/api/budgets', ['category_id' => $belanja->id, 'month' => '2026-10', 'amount' => 200000])
            ->assertCreated()
            ->json('data.id');

        $this->deleteJson("/api/budgets/{$foreign->id}")->assertNotFound();
        $this->deleteJson("/api/budgets/{$id}")->assertOk();
        $this->deleteJson("/api/budgets/{$id}")->assertNotFound();
    }
}