# Create the inference dataset

library(data.table)
library(dplyr)
library(tidyr)
library(stringr)
library(R.utils)

# Input paths
path_intermediary_1 <- "../entity_linking_2022/google/data/entity_linking_results_google_2022.csv.gz"
# Output paths
path_prepared_for_absa <- "data/google2022_prepared_for_ABSA.csv"

df <- fread(path_intermediary_1, encoding = "UTF-8", data.table = F)

df$detected_entities <- df$text_detected_entities
df$start <- df$text_start
df$end <- df$text_end

df <- df %>% select(-c(text_detected_entities, text_start, text_end))

df2 <- df[df$detected_entities != "[]",]

# Extract the character indices
python_to_r_list <- function(x){
  
  x %>%
    str_remove_all(" ") %>%
    str_remove_all("\\[") %>%
    str_remove_all("\\]") %>%
    str_split(",")
  
}

df2$start <- python_to_r_list(df2$start)
df2$end <- python_to_r_list(df2$end)
df2$detected_entities <- python_to_r_list(df2$detected_entities)

# One row per detected entity
df3 <- unnest(df2, c(detected_entities, start, end))
df3$detected_entities <- str_remove_all(df3$detected_entities, "'")
df3$start <- as.numeric(df3$start)
df3$end <- as.numeric(df3$end)

df3$chunk1 <- substr(df3$text, 1, df3$start)
df3$chunk2 <- substr(df3$text, df3$end+1, nchar(df3$text))
df3$text <- paste0(df3$chunk1, "$T$", df3$chunk2)
df4 <- select(df3, -c(chunk1, chunk2))

fwrite(df4, path_prepared_for_absa)
