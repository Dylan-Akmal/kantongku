<?php

namespace App\Http\Controllers;

use App\Http\Requests\TransactionRequest;
use App\Http\Resources\TransactionResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;

class TransactionController extends Controller
{
    private const RELATIONS = [
        'wallet:id,name,type',
        'toWallet:id,name,type',
        'category:id,name,type',
    ];

    public function index(Request $request): AnonymousResourceCollection
    {
        $request->validate([
            'type' => ['nullable', Rule::in(['income', 'expense', 'transfer'])],
            'wallet_id' => ['nullable', 'integer'],
            'category_id' => ['nullable', 'integer'],
            'date_from' => ['nullable', 'date_format:Y-m-d'],
            'date_to' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:date_from'],
            'q' => ['nullable', 'string', 'max:100'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $transactions = $request->user()->transactions()
            ->with(self::RELATIONS)
            ->when($request->filled('type'), fn ($q) => $q->where('type', $request->query('type')))
            ->when($request->filled('wallet_id'), function ($q) use ($request) {
                $walletId = $request->query('wallet_id');
                $q->where(fn ($w) => $w->where('wallet_id', $walletId)->orWhere('to_wallet_id', $walletId));
            })
            ->when($request->filled('category_id'), fn ($q) => $q->where('category_id', $request->query('category_id')))
            ->when($request->filled('date_from'), fn ($q) => $q->where('transaction_date', '>=', $request->query('date_from')))
            ->when($request->filled('date_to'), fn ($q) => $q->where('transaction_date', '<=', $request->query('date_to')))
            ->when($request->filled('q'), fn ($q) => $q->where('note', 'like', '%'.$request->query('q').'%'))
            ->orderByDesc('transaction_date')
            ->orderByDesc('id')
            ->paginate($request->integer('per_page', 15))
            ->withQueryString();

        return TransactionResource::collection($transactions);
    }

    public function store(TransactionRequest $request): JsonResponse
    {
        $transaction = $request->user()->transactions()->create($this->normalize($request->validated()));

        return (new TransactionResource($transaction->load(self::RELATIONS)))
            ->additional(['message' => 'Transaksi berhasil dicatat.'])
            ->response()
            ->setStatusCode(201);
    }

    public function show(Request $request, string $id): TransactionResource
    {
        return new TransactionResource(
            $request->user()->transactions()->with(self::RELATIONS)->findOrFail($id)
        );
    }

    public function update(TransactionRequest $request, string $id): TransactionResource
    {
        $transaction = $request->user()->transactions()->findOrFail($id);

        $transaction->update($this->normalize($request->validated()));

        return (new TransactionResource($transaction->load(self::RELATIONS)))
            ->additional(['message' => 'Transaksi berhasil diperbarui.']);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        $request->user()->transactions()->findOrFail($id)->delete();

        return response()->json([
            'message' => 'Transaksi berhasil dihapus.',
        ]);
    }

    /**
     * Pastikan kolom yang tidak relevan untuk tipe transaksi dikosongkan,
     * misalnya saat transaksi diubah dari transfer menjadi pengeluaran.
     */
    private function normalize(array $data): array
    {
        return array_merge(['category_id' => null, 'to_wallet_id' => null], $data);
    }
}