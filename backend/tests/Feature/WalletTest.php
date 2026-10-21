<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesFinanceData;
use Tests\TestCase;

class WalletTest extends TestCase
{
    use CreatesFinanceData, RefreshDatabase;

    public function test_list_shows_the_default_cash_wallet(): void
    {
        $this->signIn();

        $this->getJson('/api/wallets')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Tunai')
            ->assertJsonPath('data.0.balance', 0)
            ->assertJsonPath('meta.total_balance', 0);
    }

    public function test_create_wallet_with_initial_balance(): void
    {
        $user = $this->signIn();

        $this->postJson('/api/wallets', [
            'name' => 'BCA',
            'type' => 'bank',
            'initial_balance' => 1500000,
        ])->assertCreated()
            ->assertJsonPath('data.name', 'BCA')
            ->assertJsonPath('data.balance', 1500000);

        $this->assertDatabaseHas('wallets', ['user_id' => $user->id, 'name' => 'BCA']);
    }

    public function test_initial_balance_defaults_to_zero(): void
    {
        $this->signIn();

        $this->postJson('/api/wallets', ['name' => 'GoPay', 'type' => 'ewallet'])
            ->assertCreated()
            ->assertJsonPath('data.balance', 0);
    }

    public function test_wallet_name_is_unique_per_user_but_not_across_users(): void
    {
        $this->signIn();
        $payload = ['name' => 'BCA', 'type' => 'bank'];

        $this->postJson('/api/wallets', $payload)->assertCreated();
        $this->postJson('/api/wallets', $payload)
            ->assertUnprocessable()
            ->assertJsonValidationErrors('name');

        $this->signIn();
        $this->postJson('/api/wallets', $payload)->assertCreated();
    }

    public function test_invalid_type_and_negative_balance_are_rejected(): void
    {
        $this->signIn();

        $this->postJson('/api/wallets', [
            'name' => 'Aneh',
            'type' => 'kripto',
            'initial_balance' => -5,
        ])->assertUnprocessable()->assertJsonValidationErrors(['type', 'initial_balance']);
    }

    public function test_wallet_balance_follows_transactions(): void
    {
        $user = $this->signIn();
        $bca = $this->wallet($user, 'BCA', 2000000);
        $cash = $this->cashWallet($user);
        $gaji = $this->category($user, 'Gaji', 'income');
        $makan = $this->category($user, 'Makan & Minum', 'expense');

        $this->addTransaction($user, [
            'wallet_id' => $bca->id, 'type' => 'income', 'category_id' => $gaji->id, 'amount' => 5000000,
        ]);
        $this->addTransaction($user, [
            'wallet_id' => $bca->id, 'type' => 'expense', 'category_id' => $makan->id, 'amount' => 45000,
        ]);
        $this->addTransaction($user, [
            'wallet_id' => $bca->id, 'to_wallet_id' => $cash->id, 'type' => 'transfer', 'amount' => 500000,
        ]);

        $response = $this->getJson('/api/wallets')->assertOk();
        $balances = collect($response->json('data'))->pluck('balance', 'name');

        $this->assertSame(6455000, $balances['BCA']);
        $this->assertSame(500000, $balances['Tunai']);
        $response->assertJsonPath('meta.total_balance', 6955000);
    }

    public function test_archived_wallets_are_hidden_unless_requested_and_left_out_of_the_total(): void
    {
        $user = $this->signIn();
        $old = $this->wallet($user, 'Lama', 100000);

        $this->putJson("/api/wallets/{$old->id}", ['is_archived' => true])
            ->assertOk()
            ->assertJsonPath('data.is_archived', true);

        $this->getJson('/api/wallets')
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('meta.total_balance', 0);

        $this->getJson('/api/wallets?archived=1')->assertJsonCount(2, 'data');
    }

    public function test_wallet_with_transactions_cannot_be_deleted_but_an_empty_one_can(): void
    {
        $user = $this->signIn();
        $used = $this->wallet($user, 'Dipakai');
        $empty = $this->wallet($user, 'Kosong');

        $this->addTransaction($user, [
            'wallet_id' => $used->id,
            'type' => 'income',
            'category_id' => $this->category($user, 'Gaji', 'income')->id,
            'amount' => 1000,
        ]);

        $this->deleteJson("/api/wallets/{$used->id}")->assertStatus(409);
        $this->deleteJson("/api/wallets/{$empty->id}")->assertOk();

        $this->assertDatabaseMissing('wallets', ['id' => $empty->id]);
        $this->assertDatabaseHas('wallets', ['id' => $used->id]);
    }

    public function test_other_users_wallet_is_not_accessible(): void
    {
        $owner = $this->makeUser();
        $wallet = $owner->wallets()->firstOrFail();

        $this->signIn();

        $this->getJson("/api/wallets/{$wallet->id}")->assertNotFound();
        $this->putJson("/api/wallets/{$wallet->id}", ['name' => 'Curian'])->assertNotFound();
        $this->deleteJson("/api/wallets/{$wallet->id}")->assertNotFound();
    }
}