public with sharing class ValidationEngine {

    private static final Map<String, List<ValidationRule>> VALIDATION_RULES_BY_OBEJCT = new Map<String, List<ValidationRule>>();
    private final String objectApiName;

    public ValidationEngine(SObjectType objectType) {
        objectApiName = objectType.getDescribe().getName();
    }

    public void validateRecords(List<SObject> records) {
        for (ValidationRule rule : getValidationRules(objectApiName)) {
            for (SObject record: records) {
                rule.validateRecord(record);
            }
        }
    }

    private List<ValidationRule> getValidationRules(String objectApiName) {
        if (!VALIDATION_RULES_BY_OBEJCT.containsKey(objectApiName)) {
            List<ValidationRule> validationRules = new List<ValidationRule>();
            for (Validation_Rule__mdt validationMetadata : [
                    SELECT Error_Message__c, Conditional_Logic__c,
                        Validated_Object__r.QualifiedApiName, (
                        SELECT Index__c, Filter_Value__c, Operator__c,
                            Validated_Field__r.QualifiedApiName
                        FROM Validation_Criterion__r
                    ) FROM Validation_Rule__mdt
                    WHERE Validated_Object__r.QualifiedApiName = :objectApiName
            ]) {
                validationRules.add(
                    new ValidationRule(validationMetadata)
                );
            }
            VALIDATION_RULES_BY_OBEJCT.put(
                objectApiName, validationRules
            );
        }
        return VALIDATION_RULES_BY_OBEJCT.get(objectApiName);
    }

    public class ValidationRule {
        private final String objectApiName;
        private ConditionInterpreter criteria;
        private final String errorMessage;
        public ValidationRule(Validation_Rule__mdt validationMetadata) {
            this.objectApiName = validationMetadata.Validated_Object__r.QualifiedApiName;
            errorMessage = validationMetadata.Error_Message__c;
            criteria = new ConditionInterpreter(
                validationMetadata.Conditional_Logic__c,
                getConditions(validationMetadata.Validation_Criterion__r)
            );
        }

        public void validateRecord(SObject recordToValidate) {
            if (criteria.isMatch(recordToValidate)) {
                recordToValidate.addError(errorMessage);
            }
        }

        private Map<Integer, FieldCondition> getConditions(List<Validation_Criteria__mdt> criterion) {
            Map<Integer, FieldCondition> conditions = new Map<Integer, FieldCondition>();
            for (Validation_Criteria__mdt criteria : criterion) {
                SchemaFacade schema = SchemaFacade.getInstance();
                DescribeFieldResult field = schema.getFieldDescribe(objectApiName, criteria.Validated_Field__r.QualifiedApiName);
                Parsable parser = new DisplayTypeParser(field.getType());
                conditions.put(
                    Integer.valueOf(criteria.Index__c),
                    new FieldCondition(
                        field.getSObjectField(),
                        criteria.Operator__c,
                        parser.parse(criteria.Filter_Value__c)
                    )
                );
            }
            return conditions;
        }
    }
}
