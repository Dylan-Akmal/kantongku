<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_register_creates_account_with_default_categories_and_wallet(): void
    {
        $response = $this->postJson('/api/auth/register', [
            'name' => 'Dylan Uji',
            'email' => 'dylan.uji@example.com',
            'password' => 'rahasia123',
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.user.email', 'dylan.uji@example.com')
            ->assertJsonStructure(['data' => ['user' => ['id', 'name', 'email'], 'token']]);

        $user = User::where('email', 'dylan.uji@example.com')->firstOrFail();

        $this->assertSame(12, $user->categories()->count());
        $this->assertSame(8, $user->categories()->where('type', 'expense')->count());
        $this->assertSame(4, $user->categories()->where('type', 'income')->count());
        $this->assertSame(1, $user->wallets()->count());
        $this->assertSame('Tunai', $user->wallets()->first()->name);
        $this->assertNotSame('rahasia123', $user->password);
    }

    public function test_register_rejects_duplicate_email(): void
    {
        User::factory()->create(['email' => 'dylan.uji@example.com']);

        $this->postJson('/api/auth/register', [
            'name' => 'Dylan Lain',
            'email' => 'dylan.uji@example.com',
            'password' => 'rahasia123',
        ])->assertUnprocessable()->assertJsonValidationErrors('email');
    }

    public function test_register_rejects_short_password(): void
    {
        $this->postJson('/api/auth/register', [
            'name' => 'Dylan Uji',
            'email' => 'dylan.uji@example.com',
            'password' => '123',
        ])->assertUnprocessable()->assertJsonValidationErrors('password');
    }

    public function test_login_with_correct_credentials_returns_token(): void
    {
        User::factory()->create([
            'email' => 'dylan.uji@example.com',
            'password' => 'rahasia123',
        ]);

        $this->postJson('/api/auth/login', [
            'email' => 'dylan.uji@example.com',
            'password' => 'rahasia123',
        ])->assertOk()->assertJsonStructure(['data' => ['user' => ['id', 'name', 'email'], 'token']]);
    }

    public function test_login_with_wrong_password_returns_401(): void
    {
        User::factory()->create([
            'email' => 'dylan.uji@example.com',
            'password' => 'rahasia123',
        ]);

        $this->postJson('/api/auth/login', [
            'email' => 'dylan.uji@example.com',
            'password' => 'salahbanget',
        ])->assertUnauthorized()->assertJsonPath('message', 'Email atau kata sandi salah.');
    }

    public function test_me_requires_authentication(): void
    {
        $this->getJson('/api/me')->assertUnauthorized();
    }

    public function test_me_returns_the_current_user(): void
    {
        $user = $this->signIn();

        $this->getJson('/api/me')
            ->assertOk()
            ->assertJsonPath('data.id', $user->id)
            ->assertJsonPath('data.email', $user->email);
    }

    public function test_logout_deletes_the_current_token(): void
    {
        $user = $this->makeUser();
        $token = $user->createToken('test')->plainTextToken;

        $this->withToken($token)->postJson('/api/auth/logout')->assertOk();

        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_update_profile_changes_name_and_email(): void
    {
        $user = $this->signIn();

        $this->putJson('/api/me', [
            'name' => 'Nama Baru',
            'email' => 'baru@example.com',
        ])->assertOk();

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'name' => 'Nama Baru',
            'email' => 'baru@example.com',
        ]);
    }

    public function test_update_profile_rejects_email_used_by_another_user(): void
    {
        User::factory()->create(['email' => 'dipakai@example.com']);
        $this->signIn();

        $this->putJson('/api/me', [
            'name' => 'Nama Baru',
            'email' => 'dipakai@example.com',
        ])->assertUnprocessable()->assertJsonValidationErrors('email');
    }

    public function test_change_password_rejects_wrong_current_password(): void
    {
        $user = $this->makeUser(['password' => 'rahasia123']);
        $this->signIn($user);

        $this->putJson('/api/me/password', [
            'current_password' => 'salahbanget',
            'password' => 'rahasiabaru456',
        ])->assertUnprocessable()->assertJsonValidationErrors('current_password');
    }

    public function test_change_password_updates_it_and_signs_out_other_sessions(): void
    {
        $user = $this->makeUser(['password' => 'rahasia123']);
        $current = $user->createToken('current')->plainTextToken;
        $user->createToken('other-device');

        $this->withToken($current)->putJson('/api/me/password', [
            'current_password' => 'rahasia123',
            'password' => 'rahasiabaru456',
        ])->assertOk();

        $this->assertTrue(Hash::check('rahasiabaru456', $user->fresh()->password));
        $this->assertDatabaseCount('personal_access_tokens', 1);
    }
}