package com.trustrummy.backend.security;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JwtSecretValidatorTest {

    @Test
    void rejectsDefaultSecretWhenNotAllowed() {
        JwtSecretValidator validator = new JwtSecretValidator(
                JwtSecretValidator.INSECURE_DEFAULT_SECRET, false);
        assertThatThrownBy(validator::validate)
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("default jwt.secret");
    }

    @Test
    void allowsDefaultSecretWhenExplicitlyEnabled() {
        JwtSecretValidator validator = new JwtSecretValidator(
                JwtSecretValidator.INSECURE_DEFAULT_SECRET, true);
        assertThatCode(validator::validate).doesNotThrowAnyException();
    }

    @Test
    void rejectsShortSecret() {
        JwtSecretValidator validator = new JwtSecretValidator("too-short", true);
        assertThatThrownBy(validator::validate)
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("32 bytes");
    }
}
