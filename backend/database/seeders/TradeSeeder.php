<?php

namespace Database\Seeders;

use App\Models\Trade;
use Illuminate\Database\Seeder;

class TradeSeeder extends Seeder
{
    public function run(): void
    {
        $trades = [
            'Carpintería',
            'Electricidad',
            'Gasfitería',
            'Pintura',
            'Albañilería',
            'Soldadura',
            'Jardinería',
            'Limpieza',
        ];

        foreach ($trades as $name) {
            Trade::firstOrCreate(['name' => $name]);
        }
    }
}