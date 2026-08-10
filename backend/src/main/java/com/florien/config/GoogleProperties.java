package com.florien.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "florien.google")
public record GoogleProperties(String clientId) {}
