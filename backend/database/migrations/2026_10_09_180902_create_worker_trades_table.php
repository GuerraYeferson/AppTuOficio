<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('worker_trades', function (Blueprint $table) {
            $table->id();
            $table->foreignId('worker_profile_id')
                  ->constrained('worker_profiles')
                  ->onDelete('cascade');
            $table->foreignId('trade_id')
                  ->constrained('trades')
                  ->onDelete('cascade');
            $table->timestamps();

            $table->unique(['worker_profile_id', 'trade_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('worker_trades');
    }
};