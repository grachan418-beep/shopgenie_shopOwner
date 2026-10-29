package com.example.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.api.NetworkClient
import com.example.data.models.ProductDto
import com.example.ui.cart.CartManager
import com.example.ui.components.EmptyStateCard
import com.example.ui.components.ErrorBanner
import com.example.ui.components.LoadingStateIndicator
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProductListScreen(
    networkClient: NetworkClient,
    onNavigateBack: () -> Unit,
    onNavigateDetail: (productId: Int) -> Unit,
    onNavigateAdd: () -> Unit,
    onNavigateWeightInput: (productId: Int, productName: String, pricePerKg: Double) -> Unit
) {
    var products by remember { mutableStateOf<List<ProductDto>>(emptyList()) }
    var searchQuery by remember { mutableStateOf("") }
    var selectedFilter by remember { mutableStateOf("ALL") } // ALL, UNIT, KG, LOOSE
    var isLoading by remember { mutableStateOf(true) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val coroutineScope = rememberCoroutineScope()

    fun loadProducts() {
        isLoading = true
        errorMessage = null
        coroutineScope.launch {
            try {
                val res = networkClient.apiService.getProducts()
                if (res.isSuccessful && res.body() != null) {
                    products = res.body()!!
                    isLoading = false
                } else {
                    isLoading = false
                    errorMessage = "Failed to load products (HTTP ${res.code()})"
                }
            } catch (e: Exception) {
                isLoading = false
                errorMessage = "Network error: ${e.localizedMessage}"
            }
        }
    }

    LaunchedEffect(Unit) {
        loadProducts()
    }

    val filteredProducts = products.filter {
        val matchesSearch = it.name.contains(searchQuery, ignoreCase = true) ||
                it.category.contains(searchQuery, ignoreCase = true)
        val matchesFilter = when (selectedFilter) {
            "UNIT" -> it.sellingType == "UNIT"
            "KG" -> it.sellingType == "KG"
            "LOOSE" -> it.isLoose
            else -> true
        }
        matchesSearch && matchesFilter
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Product Inventory", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { loadProducts() }) {
                        Icon(Icons.Default.Refresh, contentDescription = "Refresh")
                    }
                }
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = onNavigateAdd,
                containerColor = MaterialTheme.colorScheme.primary
            ) {
                Icon(Icons.Default.Add, contentDescription = "Add Product", tint = Color.White)
            }
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // Search Bar
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                placeholder = { Text("Search catalog by name or category...") },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                trailingIcon = {
                    if (searchQuery.isNotEmpty()) {
                        IconButton(onClick = { searchQuery = "" }) {
                            Icon(Icons.Default.Clear, contentDescription = "Clear")
                        }
                    }
                },
                singleLine = true,
                shape = RoundedCornerShape(12.dp)
            )

            // Category Filter Chips
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                FilterChip(
                    selected = selectedFilter == "ALL",
                    onClick = { selectedFilter = "ALL" },
                    label = { Text("All (${products.size})") }
                )
                FilterChip(
                    selected = selectedFilter == "UNIT",
                    onClick = { selectedFilter = "UNIT" },
                    label = { Text("Packaged (Unit)") }
                )
                FilterChip(
                    selected = selectedFilter == "KG",
                    onClick = { selectedFilter = "KG" },
                    label = { Text("By Weight (Kg)") }
                )
                FilterChip(
                    selected = selectedFilter == "LOOSE",
                    onClick = { selectedFilter = "LOOSE" },
                    label = { Text("Plain Bags") }
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            when {
                isLoading -> {
                    LoadingStateIndicator(message = "Fetching your store catalog...")
                }
                errorMessage != null -> {
                    ErrorBanner(errorMessage = errorMessage!!, onRetry = { loadProducts() })
                }
                filteredProducts.isEmpty() -> {
                    EmptyStateCard(
                        icon = Icons.Default.Inventory2,
                        title = "No Products Found",
                        description = if (searchQuery.isNotEmpty()) "No items match '$searchQuery'." else "You haven't added any products to your shop catalog yet.",
                        actionButtonText = "Add First Product",
                        onActionClick = onNavigateAdd
                    )
                }
                else -> {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        items(filteredProducts, key = { it.id }) { product ->
                            ProductCard(
                                product = product,
                                onClick = { onNavigateDetail(product.id) },
                                onAddToCart = {
                                    if (product.sellingType == "KG") {
                                        onNavigateWeightInput(product.id, product.name, product.pricePerUnit)
                                    } else {
                                        CartManager.addItem(product, 1.0)
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ProductCard(
    product: ProductDto,
    onClick: () -> Unit,
    onAddToCart: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() },
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = product.name,
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    if (product.isLoose) {
                        Spacer(modifier = Modifier.width(6.dp))
                        AssistChip(
                            onClick = {},
                            label = { Text("Plain Bag", fontSize = 10.sp) },
                            modifier = Modifier.height(24.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(4.dp))

                Text(
                    text = "${product.category} • Selling: ₹${String.format("%.2f", product.pricePerUnit)} / ${product.sellingType}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Spacer(modifier = Modifier.height(2.dp))

                Text(
                    text = "Stock: ${product.formattedQuantity ?: "${product.quantity} ${product.sellingType}"}",
                    style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
                    color = if (product.quantity <= 5) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary
                )
            }

            IconButton(
                onClick = onAddToCart,
                colors = IconButtonDefaults.iconButtonColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    contentColor = MaterialTheme.colorScheme.primary
                )
            ) {
                Icon(Icons.Default.AddShoppingCart, contentDescription = "Add to Cart")
            }
        }
    }
}
