package com.florien.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "florien.groq")
public record GroqProperties(
        String apiKey,
        String baseUrl,
        String model,
        int timeoutSeconds
) {
    public GroqProperties {
        if (baseUrl == null) baseUrl = "https://api.groq.com/openai/v1";
        if (model == null) model = "openai/gpt-oss-120b";
        if (timeoutSeconds <= 0) timeoutSeconds = 60;
    }
}
