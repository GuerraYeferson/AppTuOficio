<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\JobPostController;
use App\Http\Controllers\Api\ProfileController;
use App\Http\Controllers\Api\TradeController;
use App\Http\Controllers\Api\WorkerController;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
    Route::delete('/me', [AuthController::class, 'destroy']);

    Route::get('/trades', [TradeController::class, 'index']);
    Route::post('/trades', [TradeController::class, 'store']);
    Route::put('/trades/{id}', [TradeController::class, 'update']);
    Route::delete('/trades/{id}', [TradeController::class, 'destroy']);

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
});