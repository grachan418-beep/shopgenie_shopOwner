package com.example.data.api

import com.example.data.models.*
import okhttp3.MultipartBody
import retrofit2.Response
import retrofit2.http.*

interface ShopGenieApiService {

    // Authentication Endpoints
    @POST("api/auth/register/")
    suspend fun register(@Body payload: Map<String, String>): Response<AuthResponse>

    @POST("api/auth/login/")
    suspend fun login(@Body payload: Map<String, String>): Response<AuthResponse>

    @POST("api/auth/refresh/")
    suspend fun refreshToken(@Body payload: RefreshTokenRequest): Response<RefreshTokenResponse>

    @GET("api/auth/me/")
    suspend fun getCurrentUser(): Response<UserDto>

    // Products / Inventory Endpoints
    @GET("api/products/")
    suspend fun getProducts(): Response<List<ProductDto>>

    @POST("api/products/register/")
    suspend fun registerProduct(@Body payload: ProductCreateRequest): Response<ProductDto>

    @GET("api/products/{id}/")
    suspend fun getProductDetail(@Path("id") id: Int): Response<ProductDto>

    @PUT("api/products/{id}/")
    suspend fun updateProduct(@Path("id") id: Int, @Body payload: ProductCreateRequest): Response<ProductDto>

    @DELETE("api/products/{id}/")
    suspend fun deleteProduct(@Path("id") id: Int): Response<Unit>

    @POST("api/products/match/")
    suspend fun matchProduct(@Body payload: MatchProductRequest): Response<MatchResponse>

    // Vision Endpoints
    @POST("api/vision/capture/")
    suspend fun captureFromEsp32(@Body payload: Map<String, String>): Response<CaptureResponse>

    @POST("api/vision/embed/")
    suspend fun generateEmbedding(@Body payload: Map<String, String>): Response<EmbedResponse>

    // Checkout & Billing Endpoints
    @POST("api/checkout/accept/")
    suspend fun checkoutAccept(@Body payload: CheckoutAcceptRequest): Response<CheckoutAcceptResponse>

    @GET("api/checkout/invoices/")
    suspend fun getInvoices(): Response<List<InvoiceDto>>

    @GET("api/checkout/invoices/{id}/")
    suspend fun getInvoiceDetail(@Path("id") id: Int): Response<InvoiceDto>
}
