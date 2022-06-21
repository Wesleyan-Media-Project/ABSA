library(data.table)
library(tidyr)
library(stringi)
library(stringr)
library(dplyr)


# Input files
path_el_results_with_text <- "../../entity_linking/facebook/data/entity_linking_results_118m_v3_500.csv"
#path_el_results_without_text <- "../../entity_linking/facebook/data/entity_linking_results_118m_v3_500_notext.csv.gz"
#path_fbel_old <- "../../datasets/facebook/FBEL_cleaned_noICR_120321.csv"
path_fbel <- "../../datasets/facebook/FBEL_2.0_cleanednoICR_041222.csv"
path_cands <- "../../datasets/candidates/face_url_candidate.csv"
path_pols <- "../../datasets/candidates/face_url_politician.csv"
# Intermediary files
path_intermediary_1 <- "../data/intermediate_separate_generic_absa.rdata" # Note: used as an input in inference
path_intermediary_2 <- "../data/intermediate_separate_generic_absa_training_data.rdata"
# Output files
path_output_train <- "../data/generic_separate_absa_train.csv"
path_output_test <- "../data/generic_separate_absa_test.csv"

# Read text in
text <- fread(path_el_results_with_text,
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

save(df, file = path_intermediary_1)

#----
# End of the part that's shared with creating the inference set

# Remove everything except the paths
paths <- ls() %>% .[str_detect(., "^path_")]
rm(list = ls()[!ls() %in% paths])

df <- fread(path_fbel, data.table = F)
df$ad_id <- str_remove(df$ad_id, "_")
fecids <- fread(path_cands, data.table = F)
fecids2 <- fread(path_pols, data.table = F)

cand_vars <- paste0("CAND", 1:8)
tone_vars <- paste0("TONE", 1:8)
candid_vars <- paste0("CAND_ID", 1:8)

fecids <- select(fecids, c("candidate", "fec_id"))
fecids2$candidate <- paste(fecids2$first_name, fecids2$last_name)
fecids2$fec_id <- fecids2$fec_ids
fecids2 <- select(fecids2, c("candidate", "fec_id"))
fecids <- rbind(fecids, fecids2)

for(i in 1:length(cand_vars)){
  df[,candid_vars[i]] <- fecids$fec_id[match(as.character(df[,cand_vars[i]]), fecids$candidate)]
}

df <- select(df, c(cand_vars, candid_vars, tone_vars, ad_id))

for(i in 1:length(tone_vars)){
  df[,tone_vars[i] == "In a way to show approval or suppor"] <- 1
}

#df$TONE1[df$TONE1 == "In a way to show approval or support"]

df[df == "In a way to show approval or support"] <- 1
df[df == "In a way to show disaproval or opposition"] <- -1
df[df == "Unclear whether support or opposition"] <- 0

# Remove rows where all CANDID_IDs are NA
df <- df[-which(apply(df[,candid_vars], 1, function(x){all(is.na(x))})),]

df2 <- df %>%
  pivot_longer(cols = -ad_id,
               names_to = c(".value", "set"),
               names_pattern = "(\\w+)([0-9])"
  )

df2 <- df2[is.na(df2$CAND_ID) == F,]
df2 <- select(df2, -set)

save(df2, file = path_intermediary_2)

#----
paths <- ls() %>% .[str_detect(., "^path_")]
rm(list = ls()[!ls() %in% paths])

load(path_intermediary_1)
load(path_intermediary_2)

df <- left_join(df, df2, by = c("ad_id" = "ad_id", "detected_entities" = "CAND_ID"))

# training data
df_train <- df[is.na(df$TONE) == F,]

df_train$chunk1 <- substr(df_train$text, 1, df_train$start)
df_train$chunk2 <- substr(df_train$text, df_train$end+1, nchar(df_train$text))
df_train$text <- paste0(df_train$chunk1, "$T$", df_train$chunk2)

# former contents of prepare_entity_linked_data_for_generic_separate_absa.R
df_train$text <- str_remove_all(df_train$text, "\n")
df_train <- df_train[df_train$TONE != "",]

rec_nums <- unique(df_train$ad_id)
set.seed(123)
train <- sample(rec_nums, round(0.7*length(rec_nums)))
test <- rec_nums[!rec_nums %in% train]

train <- df_train[df_train$ad_id %in% train]
test <- df_train[df_train$ad_id %in% test]

fwrite(train, path_output_train)
fwrite(test, path_output_test)

# # Write out train file for neural net version (unused)
# train_out <- character()
# for(i in 1:nrow(train)){
#   train_out <- c(train_out, train$text[i], train$CAND[i], round(as.numeric(train$TONE[i])))
# }
# writeLines(train_out, "data/generic_separate_absa_train.xml.seg")
# 
# 
# # Write out test file for neural net version (unused)
# test_out <- character()
# for(i in 1:nrow(test)){
#   test_out <- c(test_out, test$text[i], train$CAND[i], round(as.numeric(test$TONE[i])))
# }
# writeLines(test_out, "data/generic_separate_absa_test.xml.seg")

