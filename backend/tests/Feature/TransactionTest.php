<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesFinanceData;
use Tests\TestCase;

class TransactionTest extends TestCase
{
    use CreatesFinanceData, RefreshDatabase;

    public function test_income_is_recorded_and_raises_the_wallet_balance(): void
    {
        $user = $this->signIn();
        $wallet = $this->wallet($user, 'BCA', 2000000);
        $gaji = $this->category($user, 'Gaji', 'income');

        $this->postJson('/api/transactions', [
            'type' => 'income',
            'wallet_id' => $wallet->id,
            'category_id' => $gaji->id,
            'amount' => 5000000,
            'transaction_date' => '2026-10-18',
            'note' => 'Gaji Oktober',
        ])->assertCreated()
            ->assertJsonPath('data.type', 'income')
            ->assertJsonPath('data.amount', 5000000)
            ->assertJsonPath('data.category.name', 'Gaji')
            ->assertJsonPath('data.transaction_date', '2026-10-18');

        $this->getJson("/api/wallets/{$wallet->id}")->assertJsonPath('data.balance', 7000000);
    }

    public function test_expense_lowers_the_wallet_balance(): void
    {
        $user = $this->signIn();
        $wallet = $this->wallet($user, 'BCA', 2000000);
        $makan = $this->category($user, 'Makan & Minum', 'expense');

        $this->postJson('/api/transactions', $this->expensePayload($wallet->id, $makan->id))
            ->assertCreated();

        $this->getJson("/api/wallets/{$wallet->id}")->assertJsonPath('data.balance', 1955000);
    }

    public function test_transfer_moves_money_between_wallets(): void
    {
        $user = $this->signIn();
        $bca = $this->wallet($user, 'BCA', 2000000);
        $cash = $this->cashWallet($user);

        $this->postJson('/api/transactions', [
            'type' => 'transfer',
            'wallet_id' => $bca->id,
            'to_wallet_id' => $cash->id,
            'amount' => 500000,
            'transaction_date' => '2026-10-18',
        ])->assertCreated()->assertJsonPath('data.to_wallet.name', 'Tunai');

        $this->getJson("/api/wallets/{$bca->id}")->assertJsonPath('data.balance', 1500000);
        $this->getJson("/api/wallets/{$cash->id}")->assertJsonPath('data.balance', 500000);
    }

    public function test_expense_must_use_an_expense_category(): void
    {
        $user = $this->signIn();
        $wallet = $this->wallet($user);
        $gaji = $this->category($user, 'Gaji', 'income');

        $this->postJson('/api/transactions', $this->expensePayload($wallet->id, $gaji->id))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('category_id');
    }

    public function test_income_requires_a_category(): void
    {
        $user = $this->signIn();
        $wallet = $this->wallet($user);

        $this->postJson('/api/transactions', [
            'type' => 'income',
            'wallet_id' => $wallet->id,
            'amount' => 1000,
            'transaction_date' => '2026-10-18',
        ])->assertUnprocessable()->assertJsonValidationErrors('category_id');
    }

    public function test_transfer_rules_are_enforced(): void
    {
        $user = $this->signIn();
        $bca = $this->wallet($user);
        $cash = $this->cashWallet($user);
        $makan = $this->category($user, 'Makan & Minum', 'expense');

        $this->postJson('/api/transactions', [
            'type' => 'transfer',
            'wallet_id' => $bca->id,
            'to_wallet_id' => $bca->id,
            'amount' => 1000,
            'transaction_date' => '2026-10-18',
        ])->assertUnprocessable()->assertJsonValidationErrors('to_wallet_id');

        $this->postJson('/api/transactions', [
            'type' => 'transfer',
            'wallet_id' => $bca->id,
            'to_wallet_id' => $cash->id,
            'category_id' => $makan->id,
            'amount' => 1000,
            'transaction_date' => '2026-10-18',
        ])->assertUnprocessable()->assertJsonValidationErrors('category_id');
    }

    public function test_amount_date_and_wallet_are_validated(): void
    {
        $user = $this->signIn();
        $wallet = $this->wallet($user);
        $makan = $this->category($user, 'Makan & Minum', 'expense');

        $cases = [
            'amount' => ['amount' => 0],
            'transaction_date' => ['transaction_date' => '18-10-2026'],
            'wallet_id' => ['wallet_id' => 9999],
        ];

        foreach ($cases as $field => $override) {
            $this->postJson('/api/transactions', $this->expensePayload($wallet->id, $makan->id, $override))
                ->assertUnprocessable()
                ->assertJsonValidationErrors($field);
        }
    }

    public function test_other_users_wallet_and_category_cannot_be_used(): void
    {
        $other = $this->makeUser();
        $otherWallet = $other->wallets()->firstOrFail();
        $otherCategory = $this->category($other, 'Makan & Minum', 'expense');

        $user = $this->signIn();
        $wallet = $this->wallet($user);
        $makan = $this->category($user, 'Makan & Minum', 'expense');

        $this->postJson('/api/transactions', $this->expensePayload($otherWallet->id, $makan->id))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('wallet_id');

        $this->postJson('/api/transactions', $this->expensePayload($wallet->id, $otherCategory->id))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('category_id');
    }

    public function test_archived_wallet_cannot_receive_new_transactions(): void
    {
        $user = $this->signIn();
        $wallet = $this->wallet($user, 'Lama');
        $wallet->update(['is_archived' => true]);
        $makan = $this->category($user, 'Makan & Minum', 'expense');

        $this->postJson('/api/transactions', $this->expensePayload($wallet->id, $makan->id))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('wallet_id');
    }

    public function test_list_supports_filters_search_and_pagination(): void
    {
        $user = $this->signIn();
        $bca = $this->wallet($user, 'BCA', 2000000);
        $cash = $this->cashWallet($user);
        $gaji = $this->category($user, 'Gaji', 'income');
        $makan = $this->category($user, 'Makan & Minum', 'expense');
        $hiburan = $this->category($user, 'Hiburan', 'expense');

        $this->addTransaction($user, [
            'wallet_id' => $bca->id, 'type' => 'income', 'category_id' => $gaji->id,
            'amount' => 5000000, 'note' => 'Gaji Oktober',
        ]);
        $this->addTransaction($user, [
            'wallet_id' => $bca->id, 'type' => 'expense', 'category_id' => $makan->id,
            'amount' => 45000, 'note' => 'Makan siang',
        ]);
        $this->addTransaction($user, [
            'wallet_id' => $bca->id, 'to_wallet_id' => $cash->id, 'type' => 'transfer',
            'amount' => 500000, 'note' => 'Tarik tunai',
        ]);
        $this->addTransaction($user, [
            'wallet_id' => $bca->id, 'type' => 'expense', 'category_id' => $hiburan->id,
            'amount' => 100000, 'transaction_date' => '2026-10-19', 'note' => 'Nonton',
        ]);

        $this->getJson('/api/transactions')
            ->assertOk()
            ->assertJsonCount(4, 'data')
            ->assertJsonPath('data.0.note', 'Nonton')
            ->assertJsonPath('meta.total', 4);

        $this->getJson('/api/transactions?type=expense')->assertJsonCount(2, 'data');

        $this->getJson("/api/transactions?wallet_id={$cash->id}")
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.type', 'transfer');

        $this->getJson("/api/transactions?category_id={$makan->id}")->assertJsonCount(1, 'data');
        $this->getJson('/api/transactions?q=makan')->assertJsonCount(1, 'data');
        $this->getJson('/api/transactions?date_from=2026-10-19')->assertJsonCount(1, 'data');
        $this->getJson('/api/transactions?date_from=2026-10-18&date_to=2026-10-18')->assertJsonCount(3, 'data');
        $this->getJson('/api/transactions?date_from=2026-10-20&date_to=2026-10-01')->assertUnprocessable();

        $this->getJson('/api/transactions?per_page=2')
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.last_page', 2);
    }

    public function test_update_and_delete_recalculate_the_wallet_balance(): void
    {
        $user = $this->signIn();
        $wallet = $this->wallet($user, 'BCA', 1000000);
        $makan = $this->category($user, 'Makan & Minum', 'expense');

        $id = $this->postJson('/api/transactions', $this->expensePayload($wallet->id, $makan->id))
            ->assertCreated()
            ->json('data.id');

        $this->getJson("/api/wallets/{$wallet->id}")->assertJsonPath('data.balance', 955000);

        $this->putJson("/api/transactions/{$id}", $this->expensePayload($wallet->id, $makan->id, ['amount' => 50000]))
            ->assertOk()
            ->assertJsonPath('data.amount', 50000);

        $this->getJson("/api/wallets/{$wallet->id}")->assertJsonPath('data.balance', 950000);

        $this->deleteJson("/api/transactions/{$id}")->assertOk();

        $this->getJson("/api/wallets/{$wallet->id}")->assertJsonPath('data.balance', 1000000);
    }

    public function test_changing_the_type_clears_columns_that_no_longer_apply(): void
    {
        $user = $this->signIn();
        $bca = $this->wallet($user, 'BCA');
        $cash = $this->cashWallet($user);
        $makan = $this->category($user, 'Makan & Minum', 'expense');

        $transfer = $this->addTransaction($user, [
            'wallet_id' => $bca->id, 'to_wallet_id' => $cash->id, 'type' => 'transfer', 'amount' => 1000,
        ]);

        $this->putJson("/api/transactions/{$transfer->id}", $this->expensePayload($bca->id, $makan->id, ['amount' => 1000]))
            ->assertOk();

        $this->assertDatabaseHas('transactions', [
            'id' => $transfer->id,
            'type' => 'expense',
            'to_wallet_id' => null,
            'category_id' => $makan->id,
        ]);
    }

    public function test_other_users_transactions_are_not_accessible(): void
    {
        $other = $this->makeUser();
        $transaction = $this->addTransaction($other, [
            'wallet_id' => $other->wallets()->firstOrFail()->id,
            'type' => 'income',
            'category_id' => $this->category($other, 'Gaji', 'income')->id,
        ]);

        $user = $this->signIn();
        $wallet = $user->wallets()->firstOrFail();
        $makan = $this->category($user, 'Makan & Minum', 'expense');

        $this->getJson("/api/transactions/{$transaction->id}")->assertNotFound();
        $this->putJson("/api/transactions/{$transaction->id}", $this->expensePayload($wallet->id, $makan->id))
            ->assertNotFound();
        $this->deleteJson("/api/transactions/{$transaction->id}")->assertNotFound();
    }

    private function expensePayload(int $walletId, int $categoryId, array $override = []): array
    {
        return array_merge([
            'type' => 'expense',
            'wallet_id' => $walletId,
            'category_id' => $categoryId,
            'amount' => 45000,
            'transaction_date' => '2026-10-18',
            'note' => 'Makan siang',
        ], $override);
    }
}