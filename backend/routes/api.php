<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\BudgetController;
use App\Http\Controllers\CategoryController;
use App\Http\Controllers\GroupBalanceController;
use App\Http\Controllers\GroupController;
use App\Http\Controllers\GroupExpenseController;
use App\Http\Controllers\GroupHistoryController;
use App\Http\Controllers\GroupSettlementController;
use App\Http\Controllers\ReportController;
use App\Http\Controllers\TransactionController;
use App\Http\Controllers\WalletController;
use Illuminate\Support\Facades\Route;

Route::prefix('auth')->group(function () {
    Route::post('register', [AuthController::class, 'register'])->middleware('throttle:10,1');
    Route::post('login', [AuthController::class, 'login'])->middleware('throttle:10,1');
});

Route::middleware('auth:sanctum')->group(function () {
    Route::post('auth/logout', [AuthController::class, 'logout']);

    Route::get('me', [AuthController::class, 'me']);
    Route::put('me', [AuthController::class, 'updateProfile']);
    Route::put('me/password', [AuthController::class, 'changePassword']);

    Route::apiResource('wallets', WalletController::class);
    Route::apiResource('categories', CategoryController::class)->except(['show']);
    Route::apiResource('transactions', TransactionController::class);
    Route::apiResource('budgets', BudgetController::class)->only(['index', 'store', 'destroy']);

    Route::prefix('reports')->group(function () {
        Route::get('monthly', [ReportController::class, 'monthly']);
        Route::get('daily', [ReportController::class, 'daily']);
        Route::get('export', [ReportController::class, 'export']);
    });

    Route::post('groups/join', [GroupController::class, 'join']);
    Route::apiResource('groups', GroupController::class);
    Route::post('groups/{id}/regenerate-code', [GroupController::class, 'regenerateCode']);
    Route::post('groups/{id}/leave', [GroupController::class, 'leave']);
    Route::delete('groups/{id}/members/{userId}', [GroupController::class, 'removeMember']);

    Route::get('groups/{id}/expenses', [GroupExpenseController::class, 'index']);
    Route::post('groups/{id}/expenses', [GroupExpenseController::class, 'store']);
    Route::get('groups/{id}/expenses/{expenseId}', [GroupExpenseController::class, 'show']);
    Route::put('groups/{id}/expenses/{expenseId}', [GroupExpenseController::class, 'update']);
    Route::delete('groups/{id}/expenses/{expenseId}', [GroupExpenseController::class, 'destroy']);

    Route::get('groups/{id}/balances', [GroupBalanceController::class, 'show']);

    Route::post('groups/{id}/settlements', [GroupSettlementController::class, 'store']);
    Route::delete('groups/{id}/settlements/{settlementId}', [GroupSettlementController::class, 'destroy']);

    Route::get('groups/{id}/history', [GroupHistoryController::class, 'index']);
});