# Create the inference dataset

library(dplyr)
library(data.table)
library(arrow)

# Input paths
path_intermediary_1 <- "../../data/intermediate_separate_generic_absa.parquet"
# Output paths
path_prepared_for_absa <- "../../data/140m_prepared_for_ABSA.csv.gz"

df <- as.data.frame(open_dataset(path_intermediary_1))
df$chunk1 <- substr(df$text, 1, df$start)
df$chunk2 <- substr(df$text, df$end+1, nchar(df$text))
df$text <- paste0(df$chunk1, "$T$", df$chunk2)
df <- select(df, -c(chunk1, chunk2))

write_dataset(df, "../../data/140m_prepared_for_ABSA.parquet", max_rows_per_file = 500000)
