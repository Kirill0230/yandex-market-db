package ru.kirill0230.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import lombok.RequiredArgsConstructor;
import ru.kirill0230.dto.ProductCardDto;
import ru.kirill0230.repository.ProductCardRepository;

@RestController
@RequestMapping("/products")
@RequiredArgsConstructor
public class ProductCardController {

    private final ProductCardRepository repository;

    @GetMapping("/{id}")
    public ResponseEntity<ProductCardDto> getCard(@PathVariable int id) {
        return repository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
}