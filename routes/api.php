use App\Http\Controllers\NodeRegistrationController;
use App\Http\Controllers\SystemController;
use Illuminate\Support\Facades\Route;

Route::get('/data', [SystemController::class, 'index']);
Route::get('/slow/{id}', [SystemController::class, 'slow']);
Route::get('/health', [SystemController::class, 'health']);

Route::post('/nodes/register', [NodeRegistrationController::class, 'register']);
