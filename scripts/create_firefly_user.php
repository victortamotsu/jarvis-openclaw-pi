<?php
// Script para criar usuário administrativo no Firefly III
// Execute: docker exec firefly-iii-new php /tmp/create_user.php

require '/var/www/html/bootstrap/app.php';

$app = require_once('/var/www/html/bootstrap/app.php');
$kernel = $app->make(\Illuminate\Contracts\Console\Kernel::class);

// Create application container
$app->make(\Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use App\Models\User;
use Illuminate\Support\Facades\Hash;

try {
    $user = User::create([
        'name' => 'Admin',
        'email' => 'admin@jarvis.local',
        'password' => Hash::make('Jarvis2026!'),
        'email_verified_at' => now(),
    ]);

    echo "✓ User created: " . $user->email . "\n";
    echo "✓ User ID: " . $user->id . "\n";
    
    // Create personal access token
    $token = $user->createToken('admin-token');
    echo "✓ API Token: " . $token->plainTextToken . "\n";
    
} catch (\Exception $e) {
    echo "✗ Error: " . $e->getMessage() . "\n";
}
