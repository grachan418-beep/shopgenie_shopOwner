package com.example.ui.cart

import androidx.compose.runtime.mutableStateListOf
import com.example.data.models.ProductDto

data class CartItem(
    val productId: Int,
    val name: String,
    val category: String,
    val sellingType: String, // "UNIT" or "KG"
    val unitPrice: Double,
    var quantity: Double,    // Integer units or decimal KG
    val isLoose: Boolean = false
) {
    val totalPrice: Double
        get() = unitPrice * quantity

    val formattedQuantity: String
        get() = if (sellingType == "KG") {
            String.format("%.3f kg", quantity)
        } else {
            String.format("%.0f pcs", quantity)
        }
}

object CartManager {
    val items = mutableStateListOf<CartItem>()

    fun addItem(product: ProductDto, quantity: Double) {
        val existingIndex = items.indexOfFirst { it.productId == product.id }
        if (existingIndex >= 0) {
            val existing = items[existingIndex]
            items[existingIndex] = existing.copy(quantity = existing.quantity + quantity)
        } else {
            items.add(
                CartItem(
                    productId = product.id,
                    name = product.name,
                    category = product.category,
                    sellingType = product.sellingType,
                    unitPrice = product.pricePerUnit,
                    quantity = quantity,
                    isLoose = product.isLoose
                )
            )
        }
    }

    fun addItemDirect(
        productId: Int,
        name: String,
        category: String,
        sellingType: String,
        pricePerUnit: Double,
        quantity: Double,
        isLoose: Boolean
    ) {
        val existingIndex = items.indexOfFirst { it.productId == productId }
        if (existingIndex >= 0) {
            val existing = items[existingIndex]
            items[existingIndex] = existing.copy(quantity = existing.quantity + quantity)
        } else {
            items.add(
                CartItem(
                    productId = productId,
                    name = name,
                    category = category,
                    sellingType = sellingType,
                    unitPrice = pricePerUnit,
                    quantity = quantity,
                    isLoose = isLoose
                )
            )
        }
    }

    fun updateQuantity(productId: Int, newQuantity: Double) {
        val index = items.indexOfFirst { it.productId == productId }
        if (index >= 0) {
            if (newQuantity <= 0.0) {
                items.removeAt(index)
            } else {
                items[index] = items[index].copy(quantity = newQuantity)
            }
        }
    }

    fun removeItem(productId: Int) {
        items.removeAll { it.productId == productId }
    }

    fun clear() {
        items.clear()
    }

    val totalAmount: Double
        get() = items.sumOf { it.totalPrice }

    val itemCount: Int
        get() = items.size
}
