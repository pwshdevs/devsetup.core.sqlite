using System;
using System.Data;
using System.Management.Automation;

namespace DevSetup.Core.SQLite
{
    public static class DBNullScrubber
    {
        public static PSObject DataRowToPSObject(DataRow row)
        {
            var psObject = new PSObject();

            if (row != null && (row.RowState & DataRowState.Detached) != DataRowState.Detached)
            {
                foreach (DataColumn column in row.Table.Columns)
                {
                    object value = null;
                    if (!row.IsNull(column))
                    {
                        value = row[column];
                    }

                    psObject.Properties.Add(new PSNoteProperty(column.ColumnName, value));
                }
            }

            return psObject;
        }
    }
}

