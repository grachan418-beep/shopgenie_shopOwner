package com.example.data.models

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class UserDto(
    val id: Int,
    val username: String,
    val email: String,
    @Json(name = "shop_name") val shopName: String? = null,
    @Json(name = "phone_number") val phoneNumber: String? = null
)

@JsonClass(generateAdapter = true)
data class AuthResponse(
    val message: String? = null,
    val user: UserDto? = null,
    val access: String? = null,
    val refresh: String? = null,
    val tokens: TokenPairDto? = null
) {
    val accessToken: String?
        get() = access ?: tokens?.access

    val refreshToken: String?
        get() = refresh ?: tokens?.refresh
}

@JsonClass(generateAdapter = true)
data class TokenPairDto(
    val access: String,
    val refresh: String
)

@JsonClass(generateAdapter = true)
data class RefreshTokenRequest(
    val refresh: String
)

@JsonClass(generateAdapter = true)
data class RefreshTokenResponse(
    val access: String
)

@JsonClass(generateAdapter = true)
data class ProductDto(
    val id: Int,
    val name: String,
    val category: String,
    @Json(name = "selling_type") val sellingType: String, // "UNIT" or "KG"
    @Json(name = "cost_price") val costPrice: Double,
    @Json(name = "price_per_unit") val pricePerUnit: Double,
    val quantity: Double,
    @Json(name = "formatted_quantity") val formattedQuantity: String? = null,
    @Json(name = "feature_vector") val featureVector: List<Double>? = null,
    @Json(name = "is_loose") val isLoose: Boolean = false,
    @Json(name = "image_url") val imageUrl: String? = null
) {
    val isUnit: Boolean get() = sellingType == "UNIT"
    val isKg: Boolean get() = sellingType == "KG"
}

@JsonClass(generateAdapter = true)
data class ProductCreateRequest(
    val name: String,
    val category: String,
    @Json(name = "selling_type") val sellingType: String,
    @Json(name = "cost_price") val costPrice: Double,
    @Json(name = "price_per_unit") val pricePerUnit: Double,
    val quantity: Double,
    @Json(name = "is_loose") val isLoose: Boolean = false,
    @Json(name = "feature_vector") val featureVector: List<Double>? = null,
    @Json(name = "image_url") val imageUrl: String? = null
)

@JsonClass(generateAdapter = true)
data class EmbedResponse(
    @Json(name = "feature_vector") val featureVector: List<Double>?,
    @Json(name = "is_loose") val isLoose: Boolean = false,
    @Json(name = "vector_length") val vectorLength: Int = 0
)

@JsonClass(generateAdapter = true)
data class CaptureResponse(
    val message: String,
    @Json(name = "image_base64") val imageBase64: String?,
    @Json(name = "feature_vector") val featureVector: List<Double>?,
    @Json(name = "is_loose") val isLoose: Boolean = false,
    @Json(name = "frame_size_bytes") val frameSizeBytes: Int = 0
)

@JsonClass(generateAdapter = true)
data class MatchProductRequest(
    @Json(name = "image_base64") val imageBase64: String? = null,
    @Json(name = "capture_from_esp32") val captureFromEsp32: Boolean = false,
    @Json(name = "esp32_cam_url") val esp32CamUrl: String? = null,
    @Json(name = "similarity_threshold") val similarityThreshold: Double = 0.75
)

@JsonClass(generateAdapter = true)
data class MatchResponse(
    @Json(name = "match_type") val matchType: String, // "PRODUCT" or "LOOSE_CANDIDATES"
    @Json(name = "product_id") val productId: Int? = null,
    val name: String? = null,
    val category: String? = null,
    @Json(name = "selling_type") val sellingType: String? = null,
    @Json(name = "cost_price") val costPrice: Double? = null,
    @Json(name = "price_per_unit") val pricePerUnit: Double? = null,
    val quantity: Double? = null,
    @Json(name = "formatted_quantity") val formattedQuantity: String? = null,
    val similarity: Double? = null,
    val message: String? = null,
    val candidates: List<LooseCandidateDto>? = null
)

@JsonClass(generateAdapter = true)
data class LooseCandidateDto(
    val id: Int,
    val name: String,
    val category: String,
    @Json(name = "selling_type") val sellingType: String,
    @Json(name = "price_per_unit") val pricePerUnit: Double,
    @Json(name = "cost_price") val costPrice: Double,
    val quantity: Double,
    @Json(name = "formatted_quantity") val formattedQuantity: String? = null
)

@JsonClass(generateAdapter = true)
data class CheckoutAcceptRequest(
    @Json(name = "product_id") val productId: Int,
    val quantity: Double,
    @Json(name = "invoice_id") val invoiceId: Int? = null
)

@JsonClass(generateAdapter = true)
data class CheckoutAcceptResponse(
    val message: String,
    val invoice: InvoiceDto,
    @Json(name = "billed_item") val billedItem: InvoiceItemDto,
    @Json(name = "remaining_stock") val remainingStock: RemainingStockDto? = null
)

@JsonClass(generateAdapter = true)
data class RemainingStockDto(
    @Json(name = "product_id") val productId: Int,
    @Json(name = "product_name") val productName: String,
    val quantity: Double,
    @Json(name = "formatted_quantity") val formattedQuantity: String
)

@JsonClass(generateAdapter = true)
data class InvoiceDto(
    val id: Int,
    val status: String,
    @Json(name = "total_amount") val totalAmount: Double,
    @Json(name = "created_at") val createdAt: String,
    val items: List<InvoiceItemDto> = emptyList()
)

@JsonClass(generateAdapter = true)
data class InvoiceItemDto(
    val id: Int,
    @Json(name = "product_name") val productName: String,
    val quantity: Double,
    @Json(name = "formatted_quantity") val formattedQuantity: String? = null,
    @Json(name = "unit_price") val unitPrice: Double,
    @Json(name = "total_price") val totalPrice: Double
)
