# Modified version of '01_prepare_separate_generic_absa.R'
# To only create the inference dataset based on the latest entity linking

# Input files
path_el_results <- "../../../entity_linking/facebook/data/entity_linking_results_118m_v3_500.csv"
# Output files
path_prepared_for_absa <- "../../data/separate_generic_absa_random_forest_118m.csv"


# Read text in
text <- fread(path_el_results,
              encoding = "UTF-8",
              data.table = F)

fields <- names(text)[2:9]
variations <- c("", "_detected_entities", "_start", "_end")

out <- list()
for(i in 1:length(fields)){
  text2 <- text[c("ad_id", paste0(fields[i], variations))]
  names(text2) <- c("ad_id", "text", "detected_entities", "start", "end")
  text2$field <- fields[i]
  out[[i]] <- text2
}

df <- rbindlist(out)

df <- df[df$detected_entities != "[]",]


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

out <- list()
counter <- 1
for(i in 1:nrow(df)){
  for(j in 1:length(df$detected_entities[[i]])){
    df3 <- data.frame(
      ad_id = df$ad_id[i],
      text = df$text[i],
      detected_entities = df$detected_entities[[i]][j],
      start = df$start[[i]][j],
      end = df$end[[i]][j],
      field = df$field[i]
    )
    out[[counter]] <- df3
    counter <- counter + 1
  }
  
  if (i %% 1000 == 0) {
    print(i)
  }
  
}
df2 <- rbindlist(out)

df2$detected_entities <- str_remove_all(df2$detected_entities, "'")
df2$start <- as.numeric(df2$start)
df2$end <- as.numeric(df2$end)
df <- df2

# training and inference data for 1.18m random forest

df$chunk1 <- substr(df$text, 1, df$start)
df$chunk2 <- substr(df$text, df$end+1, nchar(df$text))
df$text <- paste0(df$chunk1, "$T$", df$chunk2)
df <- select(df, -c(chunk1, chunk2))

fwrite(df, path_prepared_for_absa)
