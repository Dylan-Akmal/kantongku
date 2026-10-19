<?php

namespace App\Http\Controllers;

use App\Http\Resources\WalletResource;
use App\Models\Wallet;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;

class WalletController extends Controller
{
    private const TYPES = ['cash', 'bank', 'ewallet'];
    private const MAX_BALANCE = 999999999999;

    public function index(Request $request): AnonymousResourceCollection
    {
        $query = $request->user()->wallets()->withBalance()->orderBy('id');

        if (! $request->boolean('archived')) {
            $query->where('is_archived', false);
        }

        $wallets = $query->get();

        return WalletResource::collection($wallets)->additional([
            'meta' => [
                'total_balance' => $wallets
                    ->where('is_archived', false)
                    ->sum(fn (Wallet $wallet) => $wallet->balance),
            ],
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        $data = $request->validate([
            'name' => [
                'required', 'string', 'max:50',
                Rule::unique('wallets', 'name')->where('user_id', $user->id),
            ],
            'type' => ['required', Rule::in(self::TYPES)],
            'initial_balance' => ['nullable', 'integer', 'min:0', 'max:'.self::MAX_BALANCE],
        ]);

        $wallet = $user->wallets()->create([
            'name' => $data['name'],
            'type' => $data['type'],
            'initial_balance' => $data['initial_balance'] ?? 0,
        ]);

        return (new WalletResource($this->findOwned($request, $wallet->id)))
            ->additional(['message' => 'Dompet berhasil dibuat.'])
            ->response()
            ->setStatusCode(201);
    }

    public function show(Request $request, string $id): WalletResource
    {
        return new WalletResource($this->findOwned($request, $id));
    }

    public function update(Request $request, string $id): WalletResource
    {
        $user = $request->user();
        $wallet = $user->wallets()->findOrFail($id);

        $data = $request->validate([
            'name' => [
                'sometimes', 'required', 'string', 'max:50',
                Rule::unique('wallets', 'name')->where('user_id', $user->id)->ignore($wallet->id),
            ],
            'type' => ['sometimes', 'required', Rule::in(self::TYPES)],
            'initial_balance' => ['sometimes', 'required', 'integer', 'min:0', 'max:'.self::MAX_BALANCE],
            'is_archived' => ['sometimes', 'required', 'boolean'],
        ]);

        $wallet->update($data);

        return (new WalletResource($this->findOwned($request, $wallet->id)))
            ->additional(['message' => 'Dompet berhasil diperbarui.']);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        $wallet = $request->user()->wallets()->findOrFail($id);

        $hasTransactions = $wallet->transactions()->exists()
            || $wallet->incomingTransfers()->exists();

        if ($hasTransactions) {
            return response()->json([
                'message' => 'Dompet sudah memiliki transaksi dan tidak bisa dihapus. Arsipkan saja.',
            ], 409);
        }

        $wallet->delete();

        return response()->json([
            'message' => 'Dompet berhasil dihapus.',
        ]);
    }

    private function findOwned(Request $request, string|int $id): Wallet
    {
        return $request->user()->wallets()->withBalance()->findOrFail($id);
    }
}