<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('job_posts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete(); // el cliente
            $table->foreignId('trade_id')->nullable()->constrained()->nullOnDelete();
            $table->string('other_trade')->nullable(); // si el oficio es "Otro"
            $table->string('title');
            $table->text('description');
            $table->decimal('budget', 10, 2)->nullable(); // null = "a cotizar"
            $table->string('district');
            $table->string('location_link')->nullable(); // link de GPS opcional
            $table->string('urgency')->default('scheduled'); // urgent | scheduled
            $table->date('desired_date')->nullable();
            $table->string('status')->default('open'); // open | in_progress | closed
            $table->timestamps();
        });
    }
    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('job_posts');
    }
};
