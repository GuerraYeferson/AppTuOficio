<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class WorkerProfile extends Model
{
    protected $fillable = [
        'user_id',
        'first_name',
        'last_name',
        'phone',
        'district',
        'description',
        'years_experience',
        'is_available',
        'other_trades',
    ];

    protected function casts(): array
    {
        return [
            'is_available' => 'boolean',
            'years_experience' => 'integer',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function trades(): BelongsToMany
    {
        return $this->belongsToMany(Trade::class, 'worker_trades');
    }
}