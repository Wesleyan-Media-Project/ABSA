# Create the inference dataset

library(data.table)
library(dplyr)
library(tidyr)
library(stringr)
library(R.utils)

# Input paths
path_intermediary_1 <- "../../../entity_linking/google/data/entity_linking_results_google_2020.csv.gz"
# Output paths
path_prepared_for_absa <- "../../data/google2020_prepared_for_ABSA.csv"

df <- fread(path_intermediary_1, encoding = "UTF-8", data.table = F)

# Convert the data of the different fields to long format
# so rows are the ad_id-field level
fields <- names(df)[2:7]
variations <- c("", "_detected_entities", "_start", "_end")
out <- list()
for(i in 1:length(fields)){
  text2 <- df[c("ad_id", paste0(fields[i], variations))]
  names(text2) <- c("ad_id", "text", "detected_entities", "start", "end")
  text2$field <- fields[i]
  out[[i]] <- text2
}
df <- rbindlist(out)
df <- df[df$detected_entities != "[]",]

# Extract the character indices
python_to_r_list <- function(x){
  
  x %>%
    str_remove_all(" ") %>%
    str_remove_all("\\[") %>%
    str_remove_all("\\]") %>%
    str_split(",")
  
}
df$start <- python_to_r_list(df$start)
df$end <- python_to_r_list(df$end)
df$detected_entities <- python_to_r_list(df$detected_entities)

# One row per detected entity
df <- unnest(df, c(detected_entities, start, end))
df$detected_entities <- str_remove_all(df$detected_entities, "'")
df$start <- as.numeric(df$start)
df$end <- as.numeric(df$end)

df$chunk1 <- substr(df$text, 1, df$start)
df$chunk2 <- substr(df$text, df$end+1, nchar(df$text))
df$text <- paste0(df$chunk1, "$T$", df$chunk2)
df <- select(df, -c(chunk1, chunk2))

fwrite(df, path_prepared_for_absa)
