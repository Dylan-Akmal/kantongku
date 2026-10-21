<?php

namespace Tests;

use App\Models\User;
use App\Services\UserOnboarding;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Laravel\Sanctum\Sanctum;

abstract class TestCase extends BaseTestCase
{
    protected function setUp(): void
    {
        // Pengaman: tes menghapus semua tabel, jadi hanya boleh jalan di database *_test.
        $database = $_ENV['DB_DATABASE'] ?? getenv('DB_DATABASE');

        if (! is_string($database) || ! str_ends_with($database, '_test')) {
            throw new \RuntimeException(
                'Tes hanya boleh berjalan di database berakhiran _test (sekarang: '.var_export($database, true).').'
            );
        }

        parent::setUp();
    }

    protected function makeUser(array $attributes = []): User
    {
        $user = User::factory()->create($attributes);
        UserOnboarding::setup($user);

        return $user;
    }

    protected function signIn(?User $user = null): User
    {
        $user ??= $this->makeUser();
        Sanctum::actingAs($user);

        return $user;
    }
}