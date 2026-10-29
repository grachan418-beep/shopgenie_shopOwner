package com.example.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.example.data.api.NetworkClient
import com.example.data.models.ProductCreateRequest
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddProductScreen(
    networkClient: NetworkClient,
    initialName: String? = null,
    initialIsLoose: Boolean = false,
    onNavigateBack: () -> Unit,
    onProductAdded: () -> Unit
) {
    var name by remember { mutableStateOf(initialName ?: "") }
    var category by remember { mutableStateOf("") }
    var sellingType by remember { mutableStateOf(if (initialIsLoose) "KG" else "UNIT") } // "UNIT" or "KG"
    var costPriceStr by remember { mutableStateOf("") }
    var sellingPriceStr by remember { mutableStateOf("") }
    var initialStockStr by remember { mutableStateOf("") }
    var isLoose by remember { mutableStateOf(initialIsLoose) }

    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val coroutineScope = rememberCoroutineScope()

    fun submitProduct() {
        if (name.isBlank() || category.isBlank() || sellingPriceStr.isBlank()) {
            errorMessage = "Please enter product name, category, and selling price."
            return
        }

        val costPrice = costPriceStr.toDoubleOrNull() ?: 0.0
        val sellingPrice = sellingPriceStr.toDoubleOrNull()
        val initialStock = initialStockStr.toDoubleOrNull() ?: 0.0

        if (sellingPrice == null || sellingPrice <= 0.0) {
            errorMessage = "Please enter a valid positive selling price."
            return
        }

        isLoading = true
        errorMessage = null

        coroutineScope.launch {
            try {
                val req = ProductCreateRequest(
                    name = name.trim(),
                    category = category.trim(),
                    sellingType = sellingType,
                    costPrice = costPrice,
                    pricePerUnit = sellingPrice,
                    quantity = initialStock,
                    isLoose = isLoose
                )

                val res = networkClient.apiService.registerProduct(req)
                if (res.isSuccessful) {
                    isLoading = false
                    onProductAdded()
                } else {
                    isLoading = false
                    val err = res.errorBody()?.string() ?: ""
                    errorMessage = "Failed to register product: $err"
                }
            } catch (e: Exception) {
                isLoading = false
                errorMessage = "Network error: ${e.localizedMessage}"
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Register Product", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            if (errorMessage != null) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)
                ) {
                    Text(
                        text = errorMessage!!,
                        color = MaterialTheme.colorScheme.onErrorContainer,
                        modifier = Modifier.padding(12.dp)
                    )
                }
            }

            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("Product Name *") },
                placeholder = { Text("e.g. Tata Tea Premium, Madhur Sugar") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )

            OutlinedTextField(
                value = category,
                onValueChange = { category = it },
                label = { Text("Category *") },
                placeholder = { Text("e.g. Beverages, Staples, Grains, Biscuits") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )

            Text("Selling Metric / Packaging Type *", fontWeight = FontWeight.SemiBold)
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                FilterChip(
                    selected = sellingType == "UNIT",
                    onClick = {
                        sellingType = "UNIT"
                        isLoose = false
                    },
                    label = { Text("Unit / Packaged") },
                    leadingIcon = {
                        if (sellingType == "UNIT") Icon(Icons.Default.Check, contentDescription = null)
                    }
                )
                FilterChip(
                    selected = sellingType == "KG",
                    onClick = { sellingType = "KG" },
                    label = { Text("Kilogram (By Weight)") },
                    leadingIcon = {
                        if (sellingType == "KG") Icon(Icons.Default.Check, contentDescription = null)
                    }
                )
            }

            // Loose plain bag checkbox
            Row(verticalAlignment = Alignment.CenterVertically) {
                Checkbox(
                    checked = isLoose,
                    onCheckedChange = {
                        isLoose = it
                        if (it) sellingType = "KG"
                    }
                )
                Spacer(modifier = Modifier.width(6.dp))
                Column {
                    Text("Loose / Plain Bag Commodity", fontWeight = FontWeight.Bold)
                    Text(
                        "Enables candidate prompt when clear plastic bags are scanned",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = sellingPriceStr,
                    onValueChange = { sellingPriceStr = it },
                    label = { Text("Selling Price (₹) *") },
                    modifier = Modifier.weight(1f),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    singleLine = true
                )
                OutlinedTextField(
                    value = costPriceStr,
                    onValueChange = { costPriceStr = it },
                    label = { Text("Cost Price (₹)") },
                    modifier = Modifier.weight(1f),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    singleLine = true
                )
            }

            OutlinedTextField(
                value = initialStockStr,
                onValueChange = { initialStockStr = it },
                label = { Text(if (sellingType == "KG") "Opening Stock (in KG, e.g. 50.0)" else "Opening Stock (units)") },
                modifier = Modifier.fillMaxWidth(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                singleLine = true
            )

            Spacer(modifier = Modifier.height(12.dp))

            Button(
                onClick = { submitProduct() },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(12.dp),
                enabled = !isLoading,
                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
            ) {
                if (isLoading) {
                    CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
                } else {
                    Text("Save to Catalog", fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}
