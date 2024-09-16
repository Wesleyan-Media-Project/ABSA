library(data.table)
library(tidyr)
library(stringi)
library(stringr)
library(dplyr)
library(arrow)

# Input files
path_el_results_with_text <- "../entity_linking/facebook/data/entity_linking_results_140m_notext_new.csv.gz"

# output from fb_2020 repo 
path_ad_text <- "../fb_2020/fb_2020_140m_adid_text_clean.csv.gz"
path_fbel <- "../datasets/facebook/FBEL_2.0_cleanednoICR_041222.csv"
path_cands <- "../datasets/candidates/face_url_candidate.csv"
path_pols <- "../datasets/candidates/face_url_politician.csv"
# Intermediary files

# output from data repo
path_intermediary_1 <- "data/intermediate_separate_generic_absa.parquet" # Note: used as an input in inference
path_intermediary_2 <- "data/intermediate_separate_generic_absa_training_data.rdata"
# Output files
path_output_train <- "data/generic_separate_absa_train20.csv"
path_output_test <- "data/generic_separate_absa_test20.csv"

# Read text in
text <- fread(path_ad_text,
              encoding = "UTF-8",
              data.table = F)
text <- text %>% rename(ocr = aws_ocr_text)
text <- text %>% rename(asr = google_asr_text)
text <- text %>% select(-ad_snapshot_url)
# Read entity linking results
el_results <- fread(path_el_results_with_text,
                    encoding = "UTF-8",
                    data.table = F)
# Combine with text
text <- left_join(text, el_results, by = "ad_id")

colnames(text)
# Convert the data of the different fields to long format
# so rows are the ad_id-field level
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

write_dataset(df, path_intermediary_1, max_rows_per_file = 500000)

#----
# End of the part that's shared with creating the inference set

# Remove everything except the paths
paths <- ls() %>% .[str_detect(., "^path_")]
rm(list = ls()[!ls() %in% paths])

# Prepare the FBEL dataset
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

df <- select(df, all_of(c(cand_vars, candid_vars, tone_vars, "ad_id")))

for(i in 1:length(tone_vars)){
  df[,tone_vars[i] == "In a way to show approval or support"] <- 1
}

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

# There is one ad in the FBEL data with both a positive and negative reference to Kamala Harris
# This appears to be a mistake, the ad is positive to her
df2 <- df2[!(df2$ad_id == "x1001393136951873" & df2$CAND_ID == "WMPID2" & df2$TONE ==-1),]

# Combine the 1.4m entity linking data
# With the FBEL dataset
df <- inner_join(df, df2, by = c("ad_id" = "ad_id", "detected_entities" = "CAND_ID"))

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

train <- df_train[df_train$ad_id %in% train,]
test <- df_train[df_train$ad_id %in% test,]

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
