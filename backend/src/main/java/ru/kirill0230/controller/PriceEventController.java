package ru.kirill0230.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import lombok.RequiredArgsConstructor;
import ru.kirill0230.dto.PriceChangeEvent;
import ru.kirill0230.repository.PriceHistoryWriteRepository;

@RestController
@RequestMapping("/events/price-change")
@RequiredArgsConstructor
public class PriceEventController {

    private final PriceHistoryWriteRepository repository;
    
    @PostMapping
    public ResponseEntity<Void> logPriceChange(@RequestBody PriceChangeEvent event) {
        repository.logPriceChange(event.productDetailId(), event.price());
        return ResponseEntity.status(202).build();
    }
}