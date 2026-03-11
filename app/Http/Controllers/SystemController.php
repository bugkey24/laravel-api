<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Response;

class SystemController extends Controller
{
    /**
     * Get basic server information for load balancing testing.
     */
    public function index()
    {
        return response()->json([
            'message' => 'Hello from Laravel API',
            'server' => gethostname(),
            'ip' => request()->server('SERVER_ADDR') ?? 'N/A',
            'timestamp' => now()->toDateTimeString(),
        ]);
    }

    /**
     * Simulate a slow response for concurrency testing.
     */
    public function slow($id)
    {
        sleep(3);
        return response()->json([
            'id' => $id,
            'message' => 'This is a slow response',
            'server' => gethostname(),
            'timestamp' => now()->toDateTimeString(),
        ]);
    }

    /**
     * Health check endpoint for Nginx.
     */
    public function health()
    {
        return response()->json(['status' => 'OK'], 200);
    }
}
