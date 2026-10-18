<?php

use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\JobPostController;
use App\Http\Controllers\Api\ProfileController;
use App\Http\Controllers\Api\TradeController;
use App\Http\Controllers\Api\WorkerController;
use App\Http\Middleware\EnsureAdmin;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
    Route::delete('/me', [AuthController::class, 'destroy']);

    Route::get('/trades', [TradeController::class, 'index']);
    Route::get('/districts', fn () => response()->json([
        'districts' => config('districts.list'),
        'all' => config('districts.all'),
    ]));

    Route::get('/profile', [ProfileController::class, 'show']);
    Route::post('/profile', [ProfileController::class, 'store']);
    Route::put('/profile', [ProfileController::class, 'update']);

    Route::get('/workers', [WorkerController::class, 'index']);
    Route::get('/workers/{id}', [WorkerController::class, 'show']);

    Route::get('/job-posts', [JobPostController::class, 'index']);
    Route::post('/job-posts', [JobPostController::class, 'store']);
    Route::get('/job-posts/{id}', [JobPostController::class, 'show']);
    Route::put('/job-posts/{id}', [JobPostController::class, 'update']);
    Route::delete('/job-posts/{id}', [JobPostController::class, 'destroy']);

    // ---------- Solo administrador ----------
    Route::prefix('admin')->middleware(EnsureAdmin::class)->group(function () {
        Route::get('/users', [AdminController::class, 'users']);
        Route::get('/users/{id}', [AdminController::class, 'showUser']);
        Route::post('/users/{id}/suspend', [AdminController::class, 'suspendUser']);
        Route::post('/users/{id}/reactivate', [AdminController::class, 'reactivateUser']);

        Route::get('/job-posts', [AdminController::class, 'jobPosts']);
        Route::post('/job-posts/{id}/close', [AdminController::class, 'closeJobPost']);
        Route::delete('/job-posts/{id}', [AdminController::class, 'deleteJobPost']);

        Route::get('/trades', [AdminController::class, 'trades']);
        Route::post('/trades', [AdminController::class, 'storeTrade']);
        Route::put('/trades/{id}', [AdminController::class, 'updateTrade']);
        Route::post('/trades/{id}/toggle', [AdminController::class, 'toggleTrade']);
    });
});