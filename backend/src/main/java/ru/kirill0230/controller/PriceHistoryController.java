package ru.kirill0230.controller;

import org.springframework.web.bind.annotation.*;

import lombok.RequiredArgsConstructor;
import ru.kirill0230.dto.PriceHistoryPointDto;
import ru.kirill0230.repository.PriceHistoryReadRepository;

import java.util.List;

@RestController
@RequestMapping("/products")
@RequiredArgsConstructor
public class PriceHistoryController {

    private final PriceHistoryReadRepository repository;

    @GetMapping("/{id}/price-history")
    public List<PriceHistoryPointDto> get(
            @PathVariable int id,
            @RequestParam(defaultValue = "30") int days
    ) {
        return repository.findHistory(id, days);
    }
}