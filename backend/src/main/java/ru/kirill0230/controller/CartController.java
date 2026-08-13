package ru.kirill0230.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import lombok.RequiredArgsConstructor;
import ru.kirill0230.dto.AddToCartRequest;
import ru.kirill0230.repository.CartRepository;

import java.util.Map;

@RestController
@RequestMapping("/cart")
@RequiredArgsConstructor
public class CartController {

    private final CartRepository repository;

    @PostMapping
    public ResponseEntity<Map<String, Integer>> addToCart(@RequestBody AddToCartRequest req) {
        Integer cartItemId = repository.addToCart(
                req.userId(),
                req.productDetailId(),
                req.quantity()
        );
        return ResponseEntity.status(201).body(Map.of("cart_item_id", cartItemId));
    }
}