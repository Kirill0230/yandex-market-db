import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const USER_MAX = Number(__ENV.USER_MAX || 100);
const PRODUCT_DETAIL_MAX = Number(__ENV.PRODUCT_DETAIL_MAX || 600);

function rand(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

export const options = {
    stages: [
        { duration: '1m', target: 10 },
        { duration: '10s', target: 0 }
    ],
    thresholds: {
        http_req_failed: ['rate<0.10'],
        http_req_duration: ['p(95)<2000']
    }
};

export default function () {
    const headers = {
        'Content-Type': 'application/json'
    };

    const responses = http.batch([
        [
            'POST',
            `${BASE_URL}/cart`,
            JSON.stringify({
                userId: rand(1, USER_MAX),
                productDetailId: rand(1, PRODUCT_DETAIL_MAX),
                quantity: rand(1, 3)
            }),
            {
                headers: headers,
                tags: { profile: 'write-only', endpoint: 'cart-add' }
            }
        ],
        [
            'POST',
            `${BASE_URL}/events/price-change`,
            JSON.stringify({
                productDetailId: rand(1, PRODUCT_DETAIL_MAX),
                price: Number((rand(100, 50000) + Math.random()).toFixed(2))
            }),
            {
                headers: headers,
                tags: { profile: 'write-only', endpoint: 'price-change-event' }
            }
        ]
    ]);

    check(responses[0], {
        'cart add status is 201': (r) => r.status === 201
    });

    check(responses[1], {
        'price event status is 202': (r) => r.status === 202
    });

    sleep(1);
}