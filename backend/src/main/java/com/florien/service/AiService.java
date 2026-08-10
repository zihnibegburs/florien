package com.florien.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.florien.config.GroqProperties;
import com.florien.dto.ai.*;
import com.florien.exception.BadRequestException;
import com.florien.exception.ResourceNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class AiService {

    private static final List<String> COLORS = List.of(
            "#6C63FF", "#FF6B9D", "#4ECDC4", "#FFE66D", "#FF8B5A", "#2ECC71"
    );

    private final RestTemplate groqRestTemplate;
    private final GroqProperties groqProperties;
    private final ObjectMapper objectMapper;

    public AiBreakdownResponse breakdown(String task) {
        String prompt = """
                Sen ADHD dostu bir görev planlama asistanısın. Kullanıcının görevini küçük, yapılabilir adımlara böl.
                Her adım için gerçekçi süre (dakika) tahmin et. Türkçe yanıt ver.
                SADECE aşağıdaki JSON formatında yanıt ver, başka hiçbir metin yazma:
                {"steps":[{"title":"adım adı","durationMinutes":15}]}
                
                Görev: %s
                """.formatted(task.trim());

        JsonNode root = callGroq(prompt);
        List<AiStepDto> steps = parseSteps(root.path("steps"));
        int total = steps.stream().mapToInt(AiStepDto::durationMinutes).sum();

        return new AiBreakdownResponse(task.trim(), steps, total);
    }

    public AiPlanResponse plan(String input, LocalDate date) {
        LocalDate planDate = date != null ? date : LocalDate.now();
        String prompt = """
                Sen ADHD dostu bir günlük planlama asistanısın. Kullanıcının yazdığı düşünceleri yapılandırılmış günlük plana çevir.
                Tarih: %s
                Her görev için: başlık, süre (dakika), önerilen başlangıç saati (HH:mm formatında).
                Gerçekçi ve uygulanabilir bir plan oluştur. Türkçe yanıt ver.
                SADECE aşağıdaki JSON formatında yanıt ver:
                {"summary":"kısa özet","tasks":[{"title":"görev","durationMinutes":30,"suggestedTime":"09:00"}]}
                
                Kullanıcı yazdığı:
                %s
                """.formatted(planDate, input.trim());

        JsonNode root = callGroq(prompt);
        String summary = root.path("summary").asText("Günlük plan");
        List<AiPlannedTaskDto> tasks = parsePlannedTasks(root.path("tasks"));
        int total = tasks.stream().mapToInt(AiPlannedTaskDto::durationMinutes).sum();

        return new AiPlanResponse(planDate, summary, tasks, total);
    }

    private JsonNode callGroq(String userPrompt) {
        if (!StringUtils.hasText(groqProperties.apiKey())) {
            throw new BadRequestException(
                    "Groq API anahtarı tanımlı değil. GROQ_API_KEY ortam değişkenini ayarlayın."
            );
        }

        String url = groqProperties.baseUrl() + "/chat/completions";

        Map<String, Object> body = new HashMap<>();
        body.put("model", groqProperties.model());
        body.put("temperature", 0.3);
        body.put("response_format", Map.of("type", "json_object"));
        body.put("messages", List.of(
                Map.of("role", "system", "content", "Sen yardımcı bir planlama asistanısın. Her zaman geçerli JSON döndür."),
                Map.of("role", "user", "content", userPrompt)
        ));

        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setBearerAuth(groqProperties.apiKey());
            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(body, headers);

            String response = groqRestTemplate.postForObject(url, entity, String.class);
            if (response == null) {
                throw new BadRequestException("Groq boş yanıt döndü");
            }

            JsonNode responseNode = objectMapper.readTree(response);
            String content = responseNode.path("choices").path(0).path("message").path("content").asText();
            log.debug("Groq response: {}", content);

            return objectMapper.readTree(extractJson(content));
        } catch (RestClientException e) {
            log.error("Groq request failed: {}", e.getMessage());
            throw new BadRequestException(
                    "Groq API'ye bağlanılamadı. API anahtarını ve modeli kontrol edin: " + groqProperties.model()
            );
        } catch (BadRequestException e) {
            throw e;
        } catch (Exception e) {
            log.error("Groq parse error: {}", e.getMessage());
            throw new BadRequestException("AI yanıtı işlenemedi: " + e.getMessage());
        }
    }

    private String extractJson(String content) {
        String trimmed = content.trim();
        int start = trimmed.indexOf('{');
        int end = trimmed.lastIndexOf('}');
        if (start >= 0 && end > start) {
            return trimmed.substring(start, end + 1);
        }
        return trimmed;
    }

    private List<AiStepDto> parseSteps(JsonNode stepsNode) {
        if (!stepsNode.isArray() || stepsNode.isEmpty()) {
            throw new ResourceNotFoundException("AI adım üretemedi, tekrar dene");
        }
        List<AiStepDto> steps = new ArrayList<>();
        int i = 0;
        for (JsonNode node : stepsNode) {
            String title = node.path("title").asText("").trim();
            if (title.isEmpty()) continue;
            int duration = Math.max(5, node.path("durationMinutes").asInt(15));
            steps.add(new AiStepDto(title, duration, COLORS.get(i % COLORS.size())));
            i++;
        }
        if (steps.isEmpty()) {
            throw new BadRequestException("AI geçerli adım üretemedi");
        }
        return steps;
    }

    private List<AiPlannedTaskDto> parsePlannedTasks(JsonNode tasksNode) {
        if (!tasksNode.isArray() || tasksNode.isEmpty()) {
            throw new ResourceNotFoundException("AI plan üretemedi, tekrar dene");
        }
        List<AiPlannedTaskDto> tasks = new ArrayList<>();
        int i = 0;
        for (JsonNode node : tasksNode) {
            String title = node.path("title").asText("").trim();
            if (title.isEmpty()) continue;
            int duration = Math.max(5, node.path("durationMinutes").asInt(30));
            String time = node.path("suggestedTime").asText("09:00");
            tasks.add(new AiPlannedTaskDto(title, duration, time, COLORS.get(i % COLORS.size())));
            i++;
        }
        if (tasks.isEmpty()) {
            throw new BadRequestException("AI geçerli plan üretemedi");
        }
        return tasks;
    }
}
