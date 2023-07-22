output "cluster_endpoint" {
  value = aws_rds_cluster.default.endpoint
}

output "reader_endpoint" {
  value = aws_rds_cluster.default.reader_endpoint
}
