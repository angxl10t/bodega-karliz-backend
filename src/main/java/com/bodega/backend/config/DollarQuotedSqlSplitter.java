package com.bodega.backend.config;

import java.util.ArrayList;
import java.util.List;

/**
 * Divisor de sentencias SQL compatible con PostgreSQL (incluyendo bloques dollar-quoted
 * {@code $$ ... $$} o {@code $tag$ ... $tag$}, comentarios de línea {@code --}, comentarios
 * de bloque anidados {@code /* ... *\/} y cadenas con comillas simples o dobles).
 */
public final class DollarQuotedSqlSplitter {

    private DollarQuotedSqlSplitter() {
    }

    public static List<String> splitStatements(String sql) {
        List<String> statements = new ArrayList<>();
        if (sql == null || sql.isEmpty()) {
            return statements;
        }

        int start = (sql.charAt(0) == '\uFEFF') ? 1 : 0;
        int len = sql.length();
        StringBuilder current = new StringBuilder();

        boolean inSingleQuote = false;
        boolean inDoubleQuote = false;
        boolean inLineComment = false;
        int blockCommentDepth = 0;
        String activeDollarTag = null;

        for (int i = start; i < len; i++) {
            char c = sql.charAt(i);
            char next = (i + 1 < len) ? sql.charAt(i + 1) : '\0';

            if (inLineComment) {
                current.append(c);
                if (c == '\n') {
                    inLineComment = false;
                }
                continue;
            }

            if (blockCommentDepth > 0) {
                current.append(c);
                if (c == '/' && next == '*') {
                    blockCommentDepth++;
                    current.append(next);
                    i++;
                } else if (c == '*' && next == '/') {
                    blockCommentDepth--;
                    current.append(next);
                    i++;
                }
                continue;
            }

            if (activeDollarTag != null) {
                if (c == '$' && sql.startsWith(activeDollarTag, i)) {
                    current.append(activeDollarTag);
                    i += activeDollarTag.length() - 1;
                    activeDollarTag = null;
                } else {
                    current.append(c);
                }
                continue;
            }

            if (inSingleQuote) {
                current.append(c);
                if (c == '\'' && next == '\'') {
                    current.append(next);
                    i++;
                } else if (c == '\'') {
                    inSingleQuote = false;
                }
                continue;
            }

            if (inDoubleQuote) {
                current.append(c);
                if (c == '"' && next == '"') {
                    current.append(next);
                    i++;
                } else if (c == '"') {
                    inDoubleQuote = false;
                }
                continue;
            }

            if (c == '-' && next == '-') {
                inLineComment = true;
                current.append("--");
                i++;
                continue;
            }

            if (c == '/' && next == '*') {
                blockCommentDepth = 1;
                current.append("/*");
                i++;
                continue;
            }

            if (c == '\'') {
                inSingleQuote = true;
                current.append(c);
                continue;
            }

            if (c == '"') {
                inDoubleQuote = true;
                current.append(c);
                continue;
            }

            if (c == '$') {
                String tag = matchDollarTag(sql, i);
                if (tag != null) {
                    activeDollarTag = tag;
                    current.append(tag);
                    i += tag.length() - 1;
                    continue;
                }
            }

            if (c == ';') {
                String candidate = current.toString().trim();
                if (hasExecutableSql(candidate)) {
                    statements.add(candidate);
                }
                current.setLength(0);
                continue;
            }

            current.append(c);
        }

        String trailing = current.toString().trim();
        if (hasExecutableSql(trailing)) {
            statements.add(trailing);
        }

        return statements;
    }

    private static String matchDollarTag(String sql, int pos) {
        int len = sql.length();
        if (pos + 1 >= len) {
            return null;
        }
        char second = sql.charAt(pos + 1);
        if (second == '$') {
            return "$$";
        }
        if (!isDollarTagStart(second)) {
            return null;
        }
        for (int j = pos + 2; j < len; j++) {
            char ch = sql.charAt(j);
            if (ch == '$') {
                return sql.substring(pos, j + 1);
            }
            if (!isDollarTagBody(ch)) {
                return null;
            }
        }
        return null;
    }

    private static boolean isDollarTagStart(char c) {
        return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '_';
    }

    private static boolean isDollarTagBody(char c) {
        return isDollarTagStart(c) || (c >= '0' && c <= '9');
    }

    static boolean hasExecutableSql(String sql) {
        if (sql == null || sql.isEmpty()) {
            return false;
        }
        int len = sql.length();
        boolean inLineComment = false;
        int blockDepth = 0;

        for (int i = 0; i < len; i++) {
            char c = sql.charAt(i);
            char next = (i + 1 < len) ? sql.charAt(i + 1) : '\0';

            if (inLineComment) {
                if (c == '\n') {
                    inLineComment = false;
                }
                continue;
            }
            if (blockDepth > 0) {
                if (c == '/' && next == '*') {
                    blockDepth++;
                    i++;
                } else if (c == '*' && next == '/') {
                    blockDepth--;
                    i++;
                }
                continue;
            }
            if (c == '-' && next == '-') {
                inLineComment = true;
                i++;
                continue;
            }
            if (c == '/' && next == '*') {
                blockDepth = 1;
                i++;
                continue;
            }
            if (!Character.isWhitespace(c)) {
                return true;
            }
        }
        return false;
    }
}
