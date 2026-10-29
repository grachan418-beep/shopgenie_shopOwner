package com.example.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
import com.example.ui.components.ErrorBanner
import com.example.ui.components.LoadingStateIndicator
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProductDetailScreen(
    productId: Int,
    networkClient: NetworkClient,
    onNavigateBack: () -> Unit,
    onNavigateWeightInput: (productId: Int, productName: String, pricePerKg: Double) -> Unit
) {
    var product by remember { mutableStateOf<ProductDto?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var showDeleteConfirm by remember { mutableStateOf(false) }

    val coroutineScope = rememberCoroutineScope()

    fun loadDetail() {
        isLoading = true
        errorMessage = null
        coroutineScope.launch {
            try {
                val res = networkClient.apiService.getProductDetail(productId)
                if (res.isSuccessful && res.body() != null) {
                    product = res.body()
                    isLoading = false
                } else {
                    isLoading = false
                    errorMessage = "Failed to load product details (HTTP ${res.code()})"
                }
            } catch (e: Exception) {
                isLoading = false
                errorMessage = "Network error: ${e.localizedMessage}"
            }
        }
    }

    fun deleteProduct() {
        coroutineScope.launch {
            try {
                val res = networkClient.apiService.deleteProduct(productId)
                if (res.isSuccessful) {
                    onNavigateBack()
                } else {
                    errorMessage = "Failed to delete product."
                }
            } catch (e: Exception) {
                errorMessage = "Network error: ${e.localizedMessage}"
            }
        }
    }

    LaunchedEffect(productId) {
        loadDetail()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(product?.name ?: "Product Details", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { showDeleteConfirm = true }) {
                        Icon(Icons.Default.Delete, contentDescription = "Delete Product", tint = MaterialTheme.colorScheme.error)
                    }
                }
            )
        }
    ) { padding ->
        if (showDeleteConfirm) {
            AlertDialog(
                onDismissRequest = { showDeleteConfirm = false },
                title = { Text("Delete Product") },
                text = { Text("Are you sure you want to remove '${product?.name}' from your store catalog?") },
                confirmButton = {
                    Button(
                        onClick = {
                            showDeleteConfirm = false
                            deleteProduct()
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                    ) {
                        Text("Delete")
                    }
                },
                dismissButton = {
                    TextButton(onClick = { showDeleteConfirm = false }) {
                        Text("Cancel")
                    }
                }
            )
        }

        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when {
                isLoading -> LoadingStateIndicator(message = "Loading product information...")
                errorMessage != null -> ErrorBanner(errorMessage = errorMessage!!, onRetry = { loadDetail() })
                product != null -> {
                    val p = product!!
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(16.dp)
                            .verticalScroll(rememberScrollState()),
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(16.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                        ) {
                            Column(modifier = Modifier.padding(20.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = p.name,
                                        style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold)
                                    )
                                    SuggestionChip(
                                        onClick = {},
                                        label = { Text(p.sellingType) }
                                    )
                                }

                                Text(
                                    text = "Category: ${p.category}",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )

                                if (p.isLoose) {
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Card(
                                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer)
                                    ) {
                                        Text(
                                            text = "Plain-Bag / Loose Kirana Commodity",
                                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                                            style = MaterialTheme.typography.labelSmall,
                                            color = MaterialTheme.colorScheme.onSecondaryContainer
                                        )
                                    }
                                }
                            }
                        }

                        // Pricing & Stock Card
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(16.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                        ) {
                            Column(modifier = Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                Text("Pricing & Stock Details", fontWeight = FontWeight.Bold)

                                HorizontalDivider()

                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text("Retail Selling Price", color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text("₹${String.format("%.2f", p.pricePerUnit)} / ${p.sellingType}", fontWeight = FontWeight.Bold)
                                }

                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text("Wholesale Cost Price", color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text("₹${String.format("%.2f", p.costPrice)} / ${p.sellingType}")
                                }

                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text("Current Inventory Level", color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text(
                                        text = p.formattedQuantity ?: "${p.quantity} ${p.sellingType}",
                                        fontWeight = FontWeight.Bold,
                                        color = if (p.quantity <= 5) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary
                                    )
                                }

                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text("Visual AI Embedding", color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text(
                                        text = if (p.featureVector != null) "Trained (${p.featureVector.size}-dim)" else "Not Enrolled",
                                        color = if (p.featureVector != null) Color(0xFF16A34A) else MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(8.dp))

                        // Add to Cart Button
                        Button(
                            onClick = {
                                if (p.sellingType == "KG") {
                                    onNavigateWeightInput(p.id, p.name, p.pricePerUnit)
                                } else {
                                    CartManager.addItem(p, 1.0)
                                    onNavigateBack()
                                }
                            },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(52.dp),
                            shape = RoundedCornerShape(12.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
                        ) {
                            Icon(Icons.Default.ShoppingCart, contentDescription = null)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Add to Billing Cart", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }
}
