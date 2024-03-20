# Create the inference dataset

library(data.table)
library(dplyr)
library(tidyr)
library(stringr)
library(R.utils)

# Input paths
path_intermediary_1 <- "../entity_linking_2022/facebook/data/entity_linking_results_fb22_new.csv.gz"
# Output paths
path_prepared_for_absa <- "data/fb2022_prepared_for_ABSA.csv"

df <- fread(path_intermediary_1, encoding = "UTF-8")

# Transform the Python-based detected entities field so it can be split later
df <- df %>% mutate(across(c(text_detected_entities, text_start, text_end), str_remove_all, "\\[|\\]|\\'"))
df <- df %>% mutate(across(c(text_detected_entities, text_start, text_end), str_split, ", "))

# Remove all ads with no detected entities
df <- df %>% filter(text_detected_entities != "")

# Unnest multiple detected entities
df <- unnest(df, cols = c(text_detected_entities, text_start, text_end))

df$text_start <- as.numeric(df$text_start)
df$text_end <- as.numeric(df$text_end)

df$chunk1 <- substr(df$text, 1, df$text_start)
df$chunk2 <- substr(df$text, df$text_end+1, nchar(df$text))
df$text <- paste0(df$chunk1, "$T$", df$chunk2)
df <- select(df, -c(chunk1, chunk2))

fwrite(df, path_prepared_for_absa)
