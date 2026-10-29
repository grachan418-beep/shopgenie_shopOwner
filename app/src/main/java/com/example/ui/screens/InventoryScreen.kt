package com.example.ui.screens

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
import com.example.ui.components.EmptyStateCard
import com.example.ui.components.ErrorBanner
import com.example.ui.components.LoadingStateIndicator
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InventoryScreen(
    networkClient: NetworkClient,
    onNavigateBack: () -> Unit,
    onNavigateAddProduct: () -> Unit
) {
    var products by remember { mutableStateOf<List<ProductDto>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val coroutineScope = rememberCoroutineScope()

    fun loadInventory() {
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
                    errorMessage = "Failed to load inventory."
                }
            } catch (e: Exception) {
                isLoading = false
                errorMessage = "Network error: ${e.localizedMessage}"
            }
        }
    }

    LaunchedEffect(Unit) {
        loadInventory()
    }

    val totalItems = products.size
    val lowStockItems = products.filter { it.quantity <= 5.0 }
    val totalStockValue = products.sumOf { it.pricePerUnit * it.quantity }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Store Inventory Health", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { loadInventory() }) {
                        Icon(Icons.Default.Refresh, contentDescription = "Refresh")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when {
                isLoading -> LoadingStateIndicator(message = "Calculating inventory levels...")
                errorMessage != null -> ErrorBanner(errorMessage = errorMessage!!, onRetry = { loadInventory() })
                products.isEmpty() -> {
                    EmptyStateCard(
                        icon = Icons.Default.Warehouse,
                        title = "No Inventory Items",
                        description = "Add catalog products to monitor stock quantities and low-stock alerts.",
                        actionButtonText = "Add Product",
                        onActionClick = onNavigateAddProduct
                    )
                }
                else -> {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(16.dp)
                    ) {
                        // Inventory Summary Row
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            Card(
                                modifier = Modifier.weight(1f),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                            ) {
                                Column(modifier = Modifier.padding(14.dp)) {
                                    Text("Total SKUs", style = MaterialTheme.typography.bodySmall)
                                    Text("$totalItems", style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold))
                                }
                            }
                            Card(
                                modifier = Modifier.weight(1f),
                                colors = CardDefaults.cardColors(
                                    containerColor = if (lowStockItems.isNotEmpty()) MaterialTheme.colorScheme.errorContainer else MaterialTheme.colorScheme.surfaceVariant
                                )
                            ) {
                                Column(modifier = Modifier.padding(14.dp)) {
                                    Text("Low Stock (<5)", style = MaterialTheme.typography.bodySmall)
                                    Text(
                                        "${lowStockItems.size}",
                                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                                        color = if (lowStockItems.isNotEmpty()) MaterialTheme.colorScheme.onErrorContainer else MaterialTheme.colorScheme.onSurface
                                    )
                                }
                            }
                            Card(
                                modifier = Modifier.weight(1.2f),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
                            ) {
                                Column(modifier = Modifier.padding(14.dp)) {
                                    Text("Est. Valuation", style = MaterialTheme.typography.bodySmall)
                                    Text("₹${String.format("%.0f", totalStockValue)}", style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold))
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        Text("Stock Level Breakdown", fontWeight = FontWeight.Bold)

                        Spacer(modifier = Modifier.height(8.dp))

                        LazyColumn(
                            modifier = Modifier.fillMaxSize(),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            items(products, key = { it.id }) { p ->
                                val isLow = p.quantity <= 5.0
                                Card(
                                    modifier = Modifier.fillMaxWidth(),
                                    colors = CardDefaults.cardColors(
                                        containerColor = if (isLow) MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.3f) else MaterialTheme.colorScheme.surface
                                    ),
                                    shape = RoundedCornerShape(10.dp)
                                ) {
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(14.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Column(modifier = Modifier.weight(1f)) {
                                            Text(p.name, fontWeight = FontWeight.SemiBold)
                                            Text(
                                                text = "${p.category} • Selling: ₹${String.format("%.2f", p.pricePerUnit)} / ${p.sellingType}",
                                                style = MaterialTheme.typography.bodySmall,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant
                                            )
                                        }

                                        Column(horizontalAlignment = Alignment.End) {
                                            Text(
                                                text = p.formattedQuantity ?: "${p.quantity} ${p.sellingType}",
                                                fontWeight = FontWeight.Bold,
                                                color = if (isLow) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface
                                            )
                                            if (isLow) {
                                                Text(
                                                    text = "REORDER SOON",
                                                    fontSize = 10.sp,
                                                    fontWeight = FontWeight.Bold,
                                                    color = MaterialTheme.colorScheme.error
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
