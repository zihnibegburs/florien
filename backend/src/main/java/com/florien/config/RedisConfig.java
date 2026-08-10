package com.florien.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.RedisStandaloneConfiguration;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.core.StringRedisTemplate;

import java.net.URI;

@Configuration
@ConditionalOnProperty(name = "REDIS_URL")
public class RedisConfig {

    @Bean
    public LettuceConnectionFactory redisConnectionFactory(@Value("${REDIS_URL}") String redisUrl) {
        URI uri = URI.create(redisUrl);
        RedisStandaloneConfiguration config = new RedisStandaloneConfiguration();
        config.setHostName(uri.getHost());
        config.setPort(uri.getPort() > 0 ? uri.getPort() : 6379);
        if (uri.getUserInfo() != null) {
            String password = uri.getUserInfo().split(":", 2)[1];
            config.setPassword(password);
        }
        return new LettuceConnectionFactory(config);
    }

    @Bean
    public StringRedisTemplate stringRedisTemplate(LettuceConnectionFactory connectionFactory) {
        return new StringRedisTemplate(connectionFactory);
    }
}
