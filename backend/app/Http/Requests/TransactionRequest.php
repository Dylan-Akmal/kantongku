<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class TransactionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $userId = $this->user()->id;
        $type = $this->input('type');

        $activeWallet = Rule::exists('wallets', 'id')->where(
            fn ($q) => $q->where('user_id', $userId)->where('is_archived', false)
        );

        $rules = [
            'type' => ['required', Rule::in(['income', 'expense', 'transfer'])],
            'wallet_id' => ['required', 'integer', $activeWallet],
            'amount' => ['required', 'integer', 'min:1', 'max:999999999999'],
            'transaction_date' => ['required', 'date_format:Y-m-d'],
            'note' => ['nullable', 'string', 'max:255'],
        ];

        if ($type === 'transfer') {
            $rules['to_wallet_id'] = ['required', 'integer', 'different:wallet_id', $activeWallet];
            $rules['category_id'] = ['prohibited'];
        } else {
            $rules['category_id'] = [
                'required', 'integer',
                Rule::exists('categories', 'id')->where(
                    fn ($q) => $q->where('user_id', $userId)->where('type', $type)
                ),
            ];
            $rules['to_wallet_id'] = ['prohibited'];
        }

        return $rules;
    }
}