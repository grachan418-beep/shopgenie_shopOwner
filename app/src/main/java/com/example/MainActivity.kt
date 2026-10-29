package com.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.Crossfade
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.example.data.api.NetworkClient
import com.example.data.models.MatchResponse
import com.example.ui.cart.CartManager
import com.example.ui.navigation.Screen
import com.example.ui.screens.*
import com.example.ui.theme.MyApplicationTheme

class MainActivity : ComponentActivity() {

    private lateinit var networkClient: NetworkClient

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        networkClient = NetworkClient.getInstance(this)

        setContent {
            MyApplicationTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    MainAppNavigation(networkClient = networkClient)
                }
            }
        }
    }
}

@Composable
fun MainAppNavigation(networkClient: NetworkClient) {
    // Navigation backstack state
    val backStack = remember { mutableStateListOf<Screen>(Screen.Splash) }
    val currentScreen = backStack.lastOrNull() ?: Screen.Splash

    fun navigateTo(screen: Screen) {
        backStack.add(screen)
    }

    fun navigateReplace(screen: Screen) {
        if (backStack.isNotEmpty()) {
            backStack.removeAt(backStack.size - 1)
        }
        backStack.add(screen)
    }

    fun popBack() {
        if (backStack.size > 1) {
            backStack.removeAt(backStack.size - 1)
        }
    }

    var pendingMatchResult by remember { mutableStateOf<MatchResponse?>(null) }

    // Intercept hardware Android back button
    BackHandler(enabled = backStack.size > 1) {
        popBack()
    }

    Crossfade(targetState = currentScreen, label = "ScreenTransition") { screen ->
        when (screen) {
            is Screen.Splash -> {
                SplashScreen(
                    networkClient = networkClient,
                    onNavigateNext = { isLoggedIn ->
                        if (isLoggedIn) {
                            navigateReplace(Screen.Home)
                        } else {
                            navigateReplace(Screen.Login)
                        }
                    }
                )
            }

            is Screen.Login -> {
                LoginScreen(
                    networkClient = networkClient,
                    onLoginSuccess = {
                        backStack.clear()
                        backStack.add(Screen.Home)
                    },
                    onNavigateRegister = {
                        navigateTo(Screen.Register)
                    }
                )
            }

            is Screen.Register -> {
                RegistrationScreen(
                    networkClient = networkClient,
                    onRegisterSuccess = {
                        backStack.clear()
                        backStack.add(Screen.Home)
                    },
                    onNavigateBackToLogin = {
                        popBack()
                    }
                )
            }

            is Screen.Home -> {
                HomeScreen(
                    networkClient = networkClient,
                    onNavigateScan = { navigateTo(Screen.CameraScan) },
                    onNavigateProducts = { navigateTo(Screen.ProductList) },
                    onNavigateInventory = { navigateTo(Screen.Inventory) },
                    onNavigateCart = { navigateTo(Screen.Cart) },
                    onNavigateAddProduct = { navigateTo(Screen.AddProduct()) },
                    onNavigateLooseSelection = { navigateTo(Screen.LooseItemSelection) },
                    onNavigateProfile = { navigateTo(Screen.Profile) }
                )
            }

            is Screen.ProductList -> {
                ProductListScreen(
                    networkClient = networkClient,
                    onNavigateBack = { popBack() },
                    onNavigateDetail = { id -> navigateTo(Screen.ProductDetail(id)) },
                    onNavigateAdd = { navigateTo(Screen.AddProduct()) },
                    onNavigateWeightInput = { id, name, price ->
                        navigateTo(Screen.WeightInput(id, name, price))
                    }
                )
            }

            is Screen.ProductDetail -> {
                ProductDetailScreen(
                    productId = screen.productId,
                    networkClient = networkClient,
                    onNavigateBack = { popBack() },
                    onNavigateWeightInput = { id, name, price ->
                        navigateTo(Screen.WeightInput(id, name, price))
                    }
                )
            }

            is Screen.AddProduct -> {
                AddProductScreen(
                    networkClient = networkClient,
                    initialName = screen.initialName,
                    initialIsLoose = screen.isLoose,
                    onNavigateBack = { popBack() },
                    onProductAdded = {
                        popBack()
                    }
                )
            }

            is Screen.Inventory -> {
                InventoryScreen(
                    networkClient = networkClient,
                    onNavigateBack = { popBack() },
                    onNavigateAddProduct = { navigateTo(Screen.AddProduct()) }
                )
            }

            is Screen.Cart -> {
                CartScreen(
                    onNavigateBack = { popBack() },
                    onNavigateCheckout = { navigateTo(Screen.Checkout) },
                    onNavigateScan = { navigateTo(Screen.CameraScan) }
                )
            }

            is Screen.Checkout -> {
                CheckoutScreen(
                    networkClient = networkClient,
                    onNavigateBack = { popBack() },
                    onCheckoutSuccess = { invoiceId ->
                        navigateReplace(Screen.InvoiceReceipt(invoiceId))
                    }
                )
            }

            is Screen.InvoiceReceipt -> {
                InvoiceReceiptScreen(
                    invoiceId = screen.invoiceId,
                    networkClient = networkClient,
                    onNavigateHome = {
                        backStack.clear()
                        backStack.add(Screen.Home)
                    }
                )
            }

            is Screen.CameraScan -> {
                CameraScanScreen(
                    networkClient = networkClient,
                    onNavigateBack = { popBack() },
                    onMatchFound = { match ->
                        pendingMatchResult = match
                        navigateTo(Screen.ScanResult(match.matchType, match.productId))
                    },
                    onNavigateLooseSelection = {
                        navigateTo(Screen.LooseItemSelection)
                    }
                )
            }

            is Screen.LooseItemSelection -> {
                LooseItemSelectionScreen(
                    networkClient = networkClient,
                    onNavigateBack = { popBack() },
                    onProductSelected = { id, name, price ->
                        navigateTo(Screen.WeightInput(id, name, price))
                    },
                    onNavigateAddProduct = {
                        navigateTo(Screen.AddProduct(isLoose = true))
                    }
                )
            }

            is Screen.WeightInput -> {
                WeightInputScreen(
                    productId = screen.productId,
                    productName = screen.productName,
                    pricePerKg = screen.pricePerKg,
                    onNavigateBack = { popBack() },
                    onWeightConfirmed = {
                        navigateTo(Screen.Cart)
                    }
                )
            }

            is Screen.ScanResult -> {
                val match = pendingMatchResult ?: MatchResponse(
                    matchType = screen.matchType,
                    productId = screen.productId
                )
                ScanResultScreen(
                    matchResult = match,
                    onNavigateBackToScan = { popBack() },
                    onAcceptProductMatch = { pid, sellingType, name, price ->
                        if (sellingType == "KG") {
                            navigateTo(Screen.WeightInput(pid, name, price))
                        } else {
                            CartManager.addItemDirect(
                                productId = pid,
                                name = name,
                                category = "Scanned",
                                sellingType = sellingType,
                                pricePerUnit = price,
                                quantity = 1.0,
                                isLoose = false
                            )
                            navigateTo(Screen.Cart)
                        }
                    },
                    onCandidateChosen = { id, name, price ->
                        navigateTo(Screen.WeightInput(id, name, price))
                    }
                )
            }

            is Screen.Profile -> {
                ProfileScreen(
                    networkClient = networkClient,
                    onNavigateBack = { popBack() },
                    onLogout = {
                        backStack.clear()
                        backStack.add(Screen.Login)
                    }
                )
            }
        }
    }
}
